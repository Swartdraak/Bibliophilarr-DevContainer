import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { runCommand } from './command-runner.js';

export interface HostState {
  deployment_method: 'docker' | 'docker-compose' | 'systemd' | 'kubernetes' | 'unknown';
  docker: boolean;
  dockerCompose: boolean;
  systemd: boolean;
  kubernetes: boolean;
  tls: string | null;
  storage: string | null;
  envNames: string[];
}

export async function inspectHost(): Promise<HostState> {
  const docker = await runCommand('docker', ['--version'], { timeoutMs: 4000 });
  const compose = await runCommand('docker', ['compose', 'version'], { timeoutMs: 4000 });
  const systemctl = await runCommand('systemctl', ['--version'], { timeoutMs: 4000 });
  const kubectl = await runCommand('kubectl', ['version', '--client'], { timeoutMs: 4000 });
  const envNames = Object.keys(process.env).filter((key) => /CODER|LLM|DOCKER|KUBERNETES|SYSTEMD|TLS|CA/i.test(key));
  const tls = process.env.SSL_CERT_FILE || process.env.REQUESTS_CA_BUNDLE || process.env.NODE_EXTRA_CA_CERTS || null;
  const storage = existsSync('/workspace-test-media') ? '/workspace-test-media' : null;
  const deployment_method = docker.exitCode === 0 ? 'docker' : systemctl.exitCode === 0 ? 'systemd' : kubectl.exitCode === 0 ? 'kubernetes' : 'unknown';
  return {
    deployment_method,
    docker: docker.exitCode === 0,
    dockerCompose: compose.exitCode === 0,
    systemd: systemctl.exitCode === 0,
    kubernetes: kubectl.exitCode === 0,
    tls,
    storage,
    envNames,
  };
}

export async function inspectReachability(url: string): Promise<boolean> {
  try {
    const response = await fetch(url, { method: 'HEAD' });
    return response.ok;
  } catch {
    return false;
  }
}