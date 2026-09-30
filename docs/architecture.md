# Arquitetura: devops-03-eks-gitops

```mermaid
flowchart TB
    Dev["Desenvolvedor"] -->|git push| GHA
    User(["Usuario"]) -->|HTTP| IGW

    subgraph GitHub["GitHub"]
        GHA["GitHub Actions<br/>build e teste"] -->|commit da nova tag| Repo["gitops/<br/>manifests"]
    end

    subgraph AWS["AWS us-east-1"]
        ECR[("ECR<br/>tag = SHA")]
        SNS["SNS<br/>topico de alertas<br/>cifrado aws/sns"]
        subgraph VPC["VPC 10.40.0.0/16"]
            IGW["Internet Gateway"]
            subgraph Pub["Subnets publicas - 2 AZs"]
                ALB["ALB"]
                NAT["NAT Gateway<br/>subnet a"]
            end
            subgraph Priv["Subnets privadas - 2 AZs"]
                subgraph EKS["EKS"]
                    Argo["Argo CD"]
                    LBC["Load Balancer<br/>Controller"]
                    App["App FastAPI<br/>HPA 2 a 6 pods"]
                    subgraph Obs["Observabilidade"]
                        Grafana["Grafana"] --> Prom["Prometheus"] --> Alert["Alertmanager"]
                    end
                end
            end
        end
    end

    Ops(["Operador"]) -.->|port-forward| Grafana
    Alert -->|publish via IRSA| SNS
    SNS -->|e-mail ALERTA / RESOLVIDO| Ops

    GHA -->|OIDC, 1 hora| ECR
    IGW --> ALB
    ALB --> App
    ALB -.-|criado via IRSA| LBC
    Repo -->|pull pelo cluster| Argo
    Argo -->|sync| App
    Argo -->|sync| Obs
    Prom -->|scrape /metrics| App
    IGW -.-|saida| NAT
    NAT -.-|0.0.0.0/0| EKS
    ECR -.->|pull da imagem via NAT| EKS

    classDef ext fill:#f1f5f9,stroke:#94a3b8,stroke-width:1.5px,color:#0f172a
    classDef ci fill:#dbeafe,stroke:#3b82f6,stroke-width:1.5px,color:#1e3a5f
    classDef reg fill:#ede9fe,stroke:#8b5cf6,stroke-width:1.5px,color:#3b2a6b
    classDef compute fill:#ffedd5,stroke:#f97316,stroke-width:1.5px,color:#7c2d12
    classDef gitops fill:#fce7f3,stroke:#db2777,stroke-width:1.5px,color:#831843
    classDef obs fill:#dcfce7,stroke:#22c55e,stroke-width:1.5px,color:#14532d
    classDef net fill:#fef9c3,stroke:#ca8a04,stroke-width:1.5px,color:#713f12

    class Dev,User,Ops ext
    class GHA,Repo ci
    class ECR,SNS reg
    class App,LBC compute
    class Argo gitops
    class Prom,Alert,Grafana obs
    class ALB,NAT,IGW net

    style GitHub fill:#f8fafc,stroke:#cbd5e1,color:#475569
    style AWS fill:#f8fafc,stroke:#cbd5e1,color:#475569
    style VPC fill:#ffffff,stroke:#94a3b8,color:#334155
    style Pub fill:#fefce8,stroke:#fde68a,color:#854d0e
    style Priv fill:#f8fafc,stroke:#cbd5e1,color:#475569
    style EKS fill:#fff7ed,stroke:#fdba74,color:#9a3412
    style Obs fill:#f0fdf4,stroke:#86efac,color:#166534
```

## Fluxo de deploy (GitOps)

1. O push na `main` que altera `app/` dispara o workflow `ci-cd.yml`.
2. O job `build-and-test` constrói a imagem com o SHA do commit em
   `APP_VERSION` e testa o container: `/health` devolvendo o SHA, `/ready`,
   `/work`, `/error` devolvendo 500 e a métrica do erro em `/metrics`.
3. Com o token OIDC do GitHub, o job assume a role do pipeline por até 1 hora
   e publica a imagem no ECR com a tag do SHA. O ECR é imutável; se a tag já
   existe (reexecução no mesmo commit), o push é pulado.
4. O job `update-manifest` roda `kustomize edit set image` em
   `gitops/demo-api/kustomization.yaml` e faz o commit como
   `github-actions[bot]`. Esse commit não dispara o workflow de novo: altera só
   `gitops/` e foi feito com o `GITHUB_TOKEN`.
5. O Argo CD compara o Git com o cluster a cada 60 s (mais até 10 s de
   jitter), detecta a nova tag e aplica. O Deployment faz rolling update, e o
   ALB só manda tráfego para o pod novo quando `/ready` responde.

A role do pipeline não tem nenhuma permissão no EKS. O `concurrency` do
workflow impede que dois pushes seguidos disputem o commit do manifesto.

## Fluxo da requisição

1. O usuário chama o ALB, na subnet pública.
2. O ALB manda direto para o IP do pod (`target-type: ip`), nas subnets
   privadas, sem passar por NodePort.
3. O ALB e o target group foram criados pelo AWS Load Balancer Controller a
   partir do Ingress da `demo-api`, usando a role IRSA do controller.

## Fluxo do alerta

1. O Prometheus coleta `/metrics` dos pods pelo ServiceMonitor a cada 15 s.
2. A PrometheusRule avalia as três regras. `DemoApiHighErrorRate` fica
   pendente quando a taxa de 5xx passa de 5% e dispara se continuar assim por
   2 minutos.
3. O Alertmanager agrupa por `alertname` e `namespace`, espera 30 s
   (`group_wait`) e roteia: `Watchdog` vai para o receiver `null`, alertas do
   namespace `demo-api` vão para o receiver `email`.
4. O receiver `email` publica no tópico SNS com SigV4, usando a role IRSA do
   Alertmanager. O template monta assunto e corpo legíveis
   (`[ALERTA]`/`[RESOLVIDO]`, severidade, resumo, início e fim em UTC).
5. O SNS entrega na assinatura de e-mail confirmada.

O RESOLVIDO sai no próximo ciclo do grupo (`group_interval` de 5 minutos),
não no instante em que o alerta some.

## Camadas e responsáveis

| Camada | Quem cria | Onde está |
|---|---|---|
| Bucket do state | Terraform (state local) | `bootstrap/` |
| VPC, subnets, NAT, flow logs | Terraform | `terraform/modules/network` |
| EKS, node group, add-ons, OIDC do cluster | Terraform | `terraform/modules/eks` |
| AWS Load Balancer Controller e sua role | Terraform (Helm) | `terraform/modules/load_balancer_controller` |
| Argo CD e a Application `root` | Terraform (Helm) | `terraform/modules/argocd` |
| ECR, SNS, roles do pipeline e do Alertmanager | Terraform | `terraform/modules/{ecr,alert_notification,pipeline_identity}` |
| kube-prometheus-stack | Argo CD | `gitops/apps/monitoring.yaml` |
| demo-api (Deployment, HPA, Ingress, métricas, alertas, dashboard) | Argo CD | `gitops/demo-api/` |

A fronteira é o Argo CD: o que roda dentro do cluster depois dele é do Git, e
o Terraform não gerencia nenhum desses objetos.

## Rede

| Faixa | Uso |
|---|---|
| `10.40.0.0/16` | VPC |
| `10.40.0.0/20`, `10.40.16.0/20` | Subnets públicas (a, b): ALB e NAT |
| `10.40.128.0/20`, `10.40.144.0/20` | Subnets privadas (a, b): nodes e pods |

As subnets são /20 porque, com a VPC CNI, cada pod recebe um IP da subnet. As
públicas têm a tag `kubernetes.io/role/elb` e as privadas
`kubernetes.io/role/internal-elb`, que o Load Balancer Controller usa para
escolher onde criar o ALB.
