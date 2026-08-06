# modules/gcp-artifact-registry

Optional. Creates one Docker Artifact Registry repository with a cleanup policy: keep the last
`keep_count` tagged versions per image name forever, delete untagged versions older than
`delete_untagged_after_days`. Skip this module if you already have a registry — `modules/gcp-cloud-run`
only needs an image digest, it doesn't care where the image is hosted.

## Usage

```hcl
module "registry" {
  source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-artifact-registry?ref=v0.1.0"

  project_id = "my-gismo-agent-host"
}

output "registry_url" {
  value = module.registry.repository_url # push here: docker push <repository_url>/my-agent:<tag>
}
```

Storage under ~0.5 GB stays within Artifact Registry's always-free tier — see
[`../../docs/cost.md`](../../docs/cost.md).
