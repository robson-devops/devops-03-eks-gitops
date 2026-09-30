resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.namespace
  create_namespace = true
  wait             = true

  values = [yamlencode({
    configs = {
      cm = {
        # Padrão é 120s + até 60s de jitter; menor tempo entre commit e cluster.
        "timeout.reconciliation"        = "60s"
        "timeout.reconciliation.jitter" = "10s"
      }
    }

    # Sem SSO, notificações nem ApplicationSet: menos pods num cluster pequeno.
    dex           = { enabled = false }
    notifications = { enabled = false }
    applicationSet = {
      replicas = 0
    }
  })]
}

# Application raiz do app-of-apps. Release separado porque o CRD
# Application só existe depois que o release acima termina.
resource "helm_release" "root_application" {
  name       = "argocd-root"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = var.namespace
  wait       = true

  values = [yamlencode({
    applications = {
      root = {
        namespace = var.namespace
        # Ao apagar a raiz, o Argo CD apaga os filhos e os recursos deles.
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source = {
          repoURL        = var.repository_url
          targetRevision = var.target_revision
          path           = var.root_path
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.namespace
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
