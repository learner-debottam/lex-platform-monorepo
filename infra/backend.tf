terraform {
  backend "s3" {
    use_lockfile = true

    region = ""
    bucket = ""
    key = ""
  }
}