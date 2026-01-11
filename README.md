<p align="center">
  <img src="public/favicon.png" alt="Daemon" width="120">
</p>

<h1 align="center">Daemon</h1>

<p align="center">
  <strong>A personal API for human connection</strong>
</p>

<p align="center">
  <a href="https://daemon.rick.rezinas.com">Live Site</a> ·
  <a href="#deployment">Deployment Guide</a> ·
  <a href="#customization">Customize</a>
</p>

<p align="center">
  <img src="public/screenshot.png" alt="Daemon Dashboard" width="800">
</p>

---

## The Vision: Connecting Humans, Not Just Devices

The future isn't about connecting refrigerators to the internet. It's about **connecting people to each other** through AI-powered personal assistants that know us, represent us, and handle the complexity of modern life on our behalf.

This is part of the [Human 3.0](https://danielmiessler.com/blog/human-3-creator-revolution) philosophy: technology should serve human flourishing, not replace human connection. Your daemon is your digital representative—it knows your preferences, your availability, your interests—and it can interact with other people's daemons to find common ground, schedule meetings, or discover shared interests.

Read more about this vision:
- [The Real Internet of Things](https://danielmiessler.com/blog/real-internet-of-things) - The full book on Digital Assistants and the future of human-AI interaction
- [AI's Predictable Path](https://danielmiessler.com/blog/ai-predictable-path-7-components-2024) - The 7 components that define where AI is heading
- [Personal AIs Will Mediate Everything](https://danielmiessler.com/blog/personal-ais-will-mediate-everything) - Why personal AI assistants will become our primary interface to the world

## What is a Daemon?

A daemon is a **public API that represents you**. It exposes the information you want to share with the world in a structured, queryable format that both humans and AI systems can access.

Think of it as your digital business card, but infinitely more powerful:
- **For humans**: A beautiful website showing who you are and what you're about
- **For AI systems**: An MCP (Model Context Protocol) server that can be queried programmatically
- **For connection**: A standardized way for your AI assistant to talk to someone else's AI assistant

## This is Real, Production Code

This repository contains production-ready daemon code. It's fully functional and can be deployed to AWS with automated scripts. Customize it with your own information and deploy your personal daemon.

## Features

- **Static Website**: Beautiful, fast Astro-based site showcasing your daemon info
- **MCP Server**: AWS Lambda-based JSON-RPC API for programmatic access
- **Private S3 + CloudFront**: Secure deployment with Origin Access Control
- **Automated Deployment**: Scripts for S3, CloudFront, Lambda, and API Gateway
- **Fully Customizable**: Edit one markdown file to update your entire daemon

## Quick Start

```bash
# Install dependencies
bun install

# Run locally
bun run dev
# Visit http://localhost:5177

# Edit your personal data
vim public/daemon.md

# Build for production
bun run build
```

## Deployment

This daemon uses **AWS infrastructure** with automated deployment scripts.

**Quick Deploy:**
```bash
# 1. Deploy to private S3
./deploy/deploy-s3.sh

# 2. Set up CloudFront with OAC
./deploy/setup-cloudfront.sh

# 3. Deploy Lambda MCP server
./deploy/deploy-lambda.sh

# 4. Set up API Gateway
./deploy/setup-api-gateway.sh
```

See detailed guides:
- **[QUICK_DEPLOY.md](QUICK_DEPLOY.md)** - Fast reference for deployment
- **[AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md)** - Complete deployment guide with architecture

**Security:** S3 bucket is PRIVATE, only accessible via CloudFront using Origin Access Control (OAC).

## Customization

1. **Edit your daemon info**: Update `public/daemon.md` with your information
   - About, mission, books, movies, preferences, predictions, TELOS framework
2. **Update branding**: Replace images in `public/` (favicon, og-image)
3. **Customize design**: Modify Astro components in `src/components/`
4. **Deploy**: Run deployment scripts (see [QUICK_DEPLOY.md](QUICK_DEPLOY.md))

## Architecture

### The Data File

The `public/daemon.md` file is the **source of truth** for your daemon's information. It uses a simple section-based format:

```markdown
[ABOUT]
Your bio goes here...

[MISSION]
Your mission statement...

[FAVORITE_BOOKS]
- Book 1
- Book 2
```

Available sections: `ABOUT`, `CURRENT_LOCATION`, `MISSION`, `TELOS`, `FAVORITE_BOOKS`, `FAVORITE_MOVIES`, `FAVORITE_PODCASTS`, `DAILY_ROUTINE`, `PREFERENCES`, `PREDICTIONS`

### How It Works

Two-component architecture:

```
User → CloudFront (with OAC) → Private S3 Bucket
                                  ↓
                            Static Website
                                  ↓
                    Fetches from MCP API (optional)

AI → API Gateway → Lambda Function → daemon.md
                                       ↓
                               JSON-RPC 2.0 Response
```

1. **Static Website** (Astro):
   - Beautiful human-readable dashboard
   - Deployed to private S3, served via CloudFront
   - Optionally fetches from MCP API for live data

2. **MCP Server** (AWS Lambda):
   - Parses `daemon.md` at runtime
   - Serves structured data via JSON-RPC 2.0
   - Accessible at `mcp.daemon.rick.rezinas.com`
   - 11 endpoints: get_about, get_mission, get_telos, etc.

3. **Security**:
   - S3 bucket is private (no public access)
   - CloudFront uses OAC to authenticate with S3
   - HTTPS enforced everywhere
   - Lambda has CORS enabled for browser access

## Why Should You Have a Daemon?

1. **Own your digital identity**: Your daemon is yours, hosted where you choose
2. **Enable AI-to-AI communication**: As AI assistants become more prevalent, they'll need standardized ways to learn about people
3. **Future-proof your online presence**: Static sites with structured data are the most resilient format
4. **Join the network**: Every daemon makes the network more valuable for everyone

## The Bigger Picture

We're building toward a future where:
- Your AI assistant can find the right person to help with a problem by querying their daemon
- Scheduling a meeting means your daemon talking to their daemon
- Professional networking happens through AI matching compatible daemons
- Serendipitous human connections are facilitated by daemon-to-daemon discovery

This isn't about replacing human interaction—it's about **enabling more of it** by removing the friction and overhead that currently prevents connection.

## Tech Stack

**Frontend:**
- [Astro](https://astro.build) - Static site generation
- [React](https://react.dev) - Interactive components
- [Tailwind CSS](https://tailwindcss.com) - Styling
- [Framer Motion](https://www.framer.com/motion/) - Animations

**Backend:**
- [AWS Lambda](https://aws.amazon.com/lambda/) - Serverless MCP API
- [API Gateway](https://aws.amazon.com/api-gateway/) - REST API endpoint
- [Bun](https://bun.sh) - Build tool and JavaScript runtime

**Infrastructure:**
- [Amazon S3](https://aws.amazon.com/s3/) - Private static file storage
- [CloudFront](https://aws.amazon.com/cloudfront/) - CDN with Origin Access Control
- [ACM](https://aws.amazon.com/certificate-manager/) - SSL certificates

**Protocol:**
- [MCP](https://modelcontextprotocol.io) - Model Context Protocol (JSON-RPC 2.0)

## Related Projects

- [Fabric](https://github.com/danielmiessler/fabric) - AI prompts for solving everyday problems
- [Human 3.0](https://human3.danielmiessler.com) - The framework for thriving in an AI world

## License

MIT - Fork it, customize it, make it yours.

---

<p align="center">
  <em>Part of the <a href="https://danielmiessler.com/projects">Unsupervised Learning</a> project ecosystem</em>
</p>
