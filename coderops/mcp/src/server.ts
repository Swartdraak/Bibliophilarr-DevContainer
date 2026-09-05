import { pathToFileURL } from 'node:url';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { defaultConfig } from './config.js';
import { inspectCapabilities } from './capabilities.js';
import { inspectInventory } from './inventory.js';
import { inspectHealth } from './health.js';
import { createChangePlan, applyChange, verifyChange } from './change.js';
import { auditOperation } from './audit.js';

const config = defaultConfig(process.env.CODEROPS_REPOSITORY_ROOT ?? process.cwd());

const server = new Server({ name: 'coderops', version: '0.1.0' }, { capabilities: { tools: {} } });

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'coderops_inventory',
      description: 'Return a normalized CoderOps inventory snapshot',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'coderops_capabilities',
      description: 'Return capability discovery results',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'coderops_health',
      description: 'Return a health report',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'coderops_plan_change',
      description: 'Create a structured change plan',
      inputSchema: {
        type: 'object',
        properties: {
          target: { type: 'string' },
          currentState: { type: 'string' },
          desiredState: { type: 'string' },
          operations: { type: 'array', items: { type: 'string' } },
          risk: { type: 'string' },
        },
        required: ['target', 'currentState', 'desiredState', 'operations', 'risk'],
      },
    },
    {
      name: 'coderops_apply_change',
      description: 'Apply a policy-controlled change plan',
      inputSchema: {
        type: 'object',
        properties: {
          plan: { type: 'object' },
          mode: { type: 'string' },
          allowR3: { type: 'boolean' },
          allowR4: { type: 'boolean' },
        },
        required: ['plan', 'mode'],
      },
    },
    {
      name: 'coderops_verify',
      description: 'Verify a change plan or target',
      inputSchema: {
        type: 'object',
        properties: {
          plan: { type: 'object' },
        },
        required: ['plan'],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const args = request.params.arguments ?? {};
  switch (request.params.name) {
    case 'coderops_inventory':
      return { content: [{ type: 'text', text: JSON.stringify(await inspectInventory(config), null, 2) }] };
    case 'coderops_capabilities': {
      const inventory = await inspectInventory(config);
      const capabilities = await inspectCapabilities(config, inventory.coder.health === 'authenticated', inventory.coder.organization, inventory.coder.version);
      return { content: [{ type: 'text', text: JSON.stringify(capabilities, null, 2) }] };
    }
    case 'coderops_health':
      return { content: [{ type: 'text', text: JSON.stringify(await inspectHealth(config), null, 2) }] };
    case 'coderops_plan_change': {
      const plan = createChangePlan(String(args.target), String(args.currentState), String(args.desiredState), Array.isArray(args.operations) ? args.operations.map(String) : [], String(args.risk) as 'R0' | 'R1' | 'R2' | 'R3' | 'R4', process.env.USER ?? 'unknown');
      await auditOperation({ operation: 'plan', planId: plan.id, target: plan.target, risk: plan.risk });
      return { content: [{ type: 'text', text: JSON.stringify(plan, null, 2) }] };
    }
    case 'coderops_apply_change': {
      const result = await applyChange(args.plan as never, String(args.mode) as 'observer' | 'operator' | 'administrator', Boolean(args.allowR3), Boolean(args.allowR4));
      return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
    }
    case 'coderops_verify':
      return { content: [{ type: 'text', text: JSON.stringify(verifyChange(args.plan as never), null, 2) }] };
    default:
      return { content: [{ type: 'text', text: `unknown tool ${request.params.name}` }], isError: true };
  }
});

export async function runServer(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  void runServer();
}