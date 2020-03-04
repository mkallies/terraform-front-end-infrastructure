# terraform-front-end-infrastructure

Infrastructure for your Front End (DIY Netlify)

## What you need to do before getting started:

1. Have a domain purchased in Route 53
2. Go into `tf-backend` folder and setup an s3 bucket to hold your state files. You can omit this if you just want to keep your TF state local

## Variables you'll need to input or have a `.env` file for:

- Bucket name (bucket_name)
- Domain name (domain_name)
- Profile (profile) - this is your AWS profile

## What this project does

1. Creates an S3 Bucket for hosting your build files
2. Creates ACM certificate for HTTPS (SSL/TLS) and validates it
3. Creates a Route53 record to point our domain to CloudFront
4. Creates CloudFront distribution in front of our S3 bucket

## Manual stuff you'll need to do

This is in the context of react (create-react-app) and GitHub Actions as our CI provider

1. Create your React project and run `npm run build`
2. Upload these files to your s3 bucket by running `aws s3 sync build/ s3://bucket_name` (You'll need to run terraform first because you need your s3 bucket to exist first)
3. Set up CI/CD with GitHub Actions

## Setting up CI/CD with GH Actions

- Here we will run tests on all PRs
- Merge into master can only happen on PRs
- Pushing to master is blocked
- Once code is merged into master, we push up our build to our s3 bucket
- Break CloudFront cache

### What we can do within our CI/CD pipeline:

- Cypress e2e tests
- visual regression testing
- a11y testing
- Lighthouse testing for performance, a11y, SEO

## Gotchas

Amazon Certificate Manager (ACM) must use an SSL cert from `us-east-1`, otherwise this won't work

## Getting started

0. Buy a domain on AWS Route 53
1. Have a project created -> `npx create-react-app my-new-project`
1. cd into `tf-backend` and run

```
terraform init
terraform plan
terraform apply
```

This will setup your backend, you can omit this if you want to keep your files local

3. cd back into main folder and run

```
terraform init
terraform plan
terraform apply
```

Enter the necessary varaibles

You may get errors, these are most likely to IAM settings. Change your IAM rules to allow TF to do it's thing.
Policies you may need to add:

- CertificateManager
- CloudFront
- Route53

If the first time you run this and you get an `InvalidViewerCertificate` try checking your AWS console to see if there is a cert in ACM under the us-east-1 region. If there is run terraform again

3. `npm install && npm run build` Build static assets

4. `aws s3 sync build/ s3://{bucket_name}`

5. Create a folder `.github` within this folder create another folder `workflows`

6. Create a file `test.yml`

Add this:

```
name: test

on: [push]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [12.x] # Can add other node versions here

    steps:
      - uses: actions/checkout@v1

      - name: Cache node_modules
        uses: actions/cache@v1
        env:
          cache-name: cache-node-modules
        with:
          path: ~/.npm
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-build-${{ env.cache-name }}-
            ${{ runner.os }}-build-
            ${{ runner.os }}-

      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v1
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm ci
      - run: npm test
```

- Test on all PRs
- Deploy on all merges to master (go to settings in your repo and configure this)
- Push new files to s3 (TODO)
- Invalidate cloudfront cache (TODO)
- ???
- Profit

6. Refresh your website!

http://domain.com -> https://domain.com
www.domain.com -> domain.com
