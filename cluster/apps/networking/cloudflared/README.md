# cloudflared

The `Deployment`, `ConfigMap`, and `Secret` setup is largely copied from the official [Cloudflare Argo Tunnel Examples repo](https://github.com/cloudflare/argo-tunnel-examples/tree/master/named-tunnel-k8s)

However, instead of manually following those steps, my Terraform script creates the actual tunnel and corresponding k8s secret :)
