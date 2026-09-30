# Validação na AWS: Projeto 3

Cada camada foi validada na AWS antes de construir a camada que depende dela.
Os comandos rodam da raiz do projeto, com o `kubectl` já configurado
(`eval "$(terraform -chdir=terraform output -raw kubeconfig_command)"`).
Os tempos são os medidos em 30/09/2026.

## 1. Rede

A rota padrão das subnets privadas precisa sair pelo NAT Gateway:

```bash
aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values="$(terraform -chdir=terraform output -raw vpc_id)" \
  --query 'RouteTables[].Routes[?DestinationCidrBlock==`0.0.0.0/0`].[NatGatewayId,GatewayId,State]' \
  --output text
```

Esperado: uma rota com `nat-...` e `active` (privadas) e uma com `igw-...` e
`active` (públicas).

As tags que o Load Balancer Controller usa para escolher as subnets:

```bash
aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$(terraform -chdir=terraform output -raw vpc_id)" \
  --query 'Subnets[].[CidrBlock,Tags[?starts_with(Key, `kubernetes.io/role`)].Key|[0]]' \
  --output text
```

Esperado: `10.40.0.0/20` e `10.40.16.0/20` com `kubernetes.io/role/elb`;
`10.40.128.0/20` e `10.40.144.0/20` com `kubernetes.io/role/internal-elb`.

## 2. EKS

```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods
```

Esperado: 2 nodes `Ready` na versão 1.35, com `INTERNAL-IP` nas subnets
privadas e sem `EXTERNAL-IP`; `aws-node`, `kube-proxy`, `coredns` e
`metrics-server` em `Running`.

O log group do control plane é o criado pelo Terraform, com retenção:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/devops-03-dev \
  --query 'logGroups[].[logGroupName,retentionInDays]' \
  --output text
```

Esperado: `/aws/eks/devops-03-dev/cluster  7`

## 3. AWS Load Balancer Controller

```bash
kubectl -n kube-system get deployment aws-load-balancer-controller
```

Esperado: `2/2` pronto. O teste descartável `tests/alb-smoke.yaml` cria um
Ingress, o controller cria o ALB e `curl` no endereço dele devolve `200`.
Apagar o Ingress remove o ALB:

```bash
kubectl apply -f tests/alb-smoke.yaml
kubectl delete -f tests/alb-smoke.yaml
```

## 4. Argo CD

```bash
kubectl -n argocd get applications
```

Esperado: `root`, `demo-api` e `monitoring` em `Synced` e `Healthy`.

**Commit até o cluster: 55 s.** Uma mudança em `gitops/demo-api/` com commit e
push foi aplicada no cluster 55 s depois, dentro do intervalo de
reconciliação de 60 s (mais até 10 s de jitter).

**Self-heal: 3 s.** Uma mudança manual no cluster, fora do Git, foi desfeita
pelo Argo CD 3 s depois:

```bash
kubectl delete namespace demo-api
kubectl get namespace demo-api -w
```

## 5. Aplicação e autoscaling

```bash
kubectl -n demo-api get deployment,hpa,pdb,ingress
```

Esperado: 2 pods prontos, HPA `2/6` com alvo de 60% de CPU, PDB com
`MIN AVAILABLE 1` e o endereço do ALB no Ingress.

Carga para acionar o HPA. Cada chamada a `/work` consome CPU pelo tempo pedido:

```bash
kubectl -n demo-api run carga \
  --image=curlimages/curl:8.16.0 \
  --restart=Never \
  --command -- sh -c \
  'while true; do curl -s -o /dev/null "http://demo-api/work?ms=500"; done'

kubectl -n demo-api get hpa demo-api -w
```

Resultado medido:

| Momento | Resultado |
|---|---|
| Decisão de escalar de 2 para 6 réplicas | ~6 s após o início da carga |
| 6 pods rodando | ~18 s depois, 3 em cada AZ |
| CPU com 6 réplicas | ainda acima do alvo; limitado pelo `maxReplicas` |
| Volta a 2 réplicas | ~2 min após o fim da carga (estabilização de 120 s) |

```bash
kubectl -n demo-api delete pod carga
```

## 6. Observabilidade e alerta

Target da aplicação coletado pelo Prometheus (1 por pod):

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Em http://localhost:9090, **Status → Targets**: `serviceMonitor/demo-api/demo-api/0`
com 2 endpoints `UP`. Em **Alerts**: `DemoApiHighErrorRate`,
`DemoApiHighLatencyP95` e `DemoApiDown` em `Inactive`.

O Alertmanager recebeu a credencial da role IRSA:

```bash
kubectl -n monitoring get pod \
  alertmanager-monitoring-kube-prometheus-alertmanager-0 \
  -o jsonpath='{.spec.containers[0].env[?(@.name=="AWS_ROLE_ARN")].value}{"\n"}'
```

Esperado: `arn:aws:iam::<conta>:role/devops-03-dev-alertmanager`

Teste de ponta a ponta, com um pod gerando erro 500:

```bash
kubectl -n demo-api run erros \
  --image=curlimages/curl:8.16.0 \
  --restart=Never \
  --command -- sh -c \
  'while true; do curl -s -o /dev/null http://demo-api/error; sleep 0.2; done'
```

| Momento | Tempo desde o primeiro erro |
|---|---|
| Alerta pendente no Prometheus | 41 s |
| Alerta disparado (`for: 2m`) | 2 min 32 s |
| E-mail `[ALERTA] DemoApiHighErrorRate - demo-api` | ~3 min |

```bash
kubectl -n demo-api delete pod erros
```

O e-mail `[RESOLVIDO]` chegou no ciclo seguinte do grupo (`group_interval` de
5 minutos). As notificações enviadas ao SNS e as falhas ficam nas métricas do
próprio Alertmanager:

```bash
kubectl -n monitoring exec \
  alertmanager-monitoring-kube-prometheus-alertmanager-0 \
  -c alertmanager -- \
  wget -qO- http://localhost:9093/metrics \
  | grep -E 'alertmanager_notifications(_failed)?_total\{integration="sns"'
```

Esperado: `alertmanager_notifications_total{integration="sns"} 2` (ALERTA e
RESOLVIDO) e todos os `failed` em `0`.

## 7. Pipeline

Push de uma mudança em `app/` às 19:46:36 UTC (commit `62c6b9d`):

| Momento | Hora (UTC) | Desde o push |
|---|---|---|
| `git push` | 19:46:36 | 0 |
| Commit do bot com a nova tag no GitHub | antes de 19:49:42 | < 3 min |
| Primeiro pod novo iniciado | 19:49:06 | 2 min 30 s |
| Segundo pod novo iniciado | 19:49:10 | 2 min 34 s |

```bash
kubectl -n demo-api get pods \
  -o custom-columns='NAME:.metadata.name,INICIO:.status.startTime,IMAGEM:.spec.containers[0].image'
```

Esperado: os pods com a imagem `...devops-03-dev:<sha completo do commit>`. O
commit do bot altera uma única linha, a do `newTag`.

## 8. Encerramento

| Passo | Resultado |
|---|---|
| `kubectl -n argocd delete application root` | 24 s; `demo-api`, `monitoring`, Ingress e ALB removidos em cascata |
| ALB e security groups `k8s-*` na VPC | nenhum |
| `terraform -chdir=terraform destroy` | 49 recursos destruídos |
| `terraform -chdir=bootstrap destroy` | bucket do state removido |
| `./scripts/verificar-cobranca.sh us-east-1` | `Nada encontrado nas regiões verificadas nem nos serviços globais.` |
