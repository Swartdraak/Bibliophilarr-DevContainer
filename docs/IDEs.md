# IDE access

All clients target `/workspaces/Bibliophilarr` through the same Coder agent and image.

* **VS Code / Insiders:** use the current Coder extension or `coder ssh`; the agent working directory opens
  the repository. Browser code-server is not claimed until its registry module matches the live server.
* **Rider:** use the current Coder/JetBrains Gateway integration or SSH remote development. Validate .NET
  indexing, build/test/debug, Git, and terminal against the installed Rider backend.
* **WebStorm:** use a distinct WebStorm backend through the same supported Gateway/SSH path. Validate Node,
  Yarn, frontend indexing, Git, and terminal independently from Rider.

Live client acceptance is **BLOCKED** because no workspace could be provisioned. No IDE-specific copies of
repository agents are created; client discovery must consume the cloned `.github` files.
