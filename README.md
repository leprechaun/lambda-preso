# Lambda?

A short talk on AWS Lambda — from server closets to serverless — plus a Hello World demo.

## Slides

`presentation.md` is built into a reveal.js deck with pandoc and [mermaid-filter](https://github.com/raghur/mermaid-filter).

```sh
sudo apt-get install pandoc
npm ci
PATH="$PWD/node_modules/.bin:$PATH" \
  pandoc presentation.md -t revealjs -s -F mermaid-filter -o index.html
```

CI builds the deck on every push to `master` and uploads it as the `slides` artifact.

## Demo

`hello-world/` is a Python Lambda that logs every object put into an S3 bucket.

```sh
cd hello-world
terraform init
terraform apply -var prefix=my-demo

echo hi > hello.txt
aws s3 cp hello.txt s3://$(terraform output -raw bucket)/
aws logs tail $(terraform output -raw log_group) --follow

terraform destroy -var prefix=my-demo
```

Deploys to `ap-southeast-1` by default (`-var region=...` to change).
