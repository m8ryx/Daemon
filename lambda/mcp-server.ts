/**
 * AWS Lambda function for MCP (Model Context Protocol) API
 * Parses daemon.md and serves data via JSON-RPC 2.0
 */

import { readFileSync } from 'fs';
import { join } from 'path';

interface DaemonData {
  about?: string;
  mission?: string;
  telos?: string;
  current_location?: string;
  preferences?: string[];
  daily_routine?: string[];
  favorite_books?: string[];
  favorite_movies?: string[];
  favorite_podcasts?: string[];
  predictions?: string[];
  last_updated?: string;
}

/**
 * Parse daemon.md file into structured data
 */
function parseDaemonMd(content: string): DaemonData {
  const sections: { [key: string]: string } = {};
  const lines = content.split('\n');
  let currentSection = '';
  let currentContent: string[] = [];

  for (const line of lines) {
    if (line.startsWith('[') && line.endsWith(']')) {
      // Save previous section
      if (currentSection) {
        sections[currentSection] = currentContent.join('\n').trim();
      }
      // Start new section
      currentSection = line.slice(1, -1).toLowerCase();
      currentContent = [];
    } else if (currentSection) {
      currentContent.push(line);
    }
  }

  // Save last section
  if (currentSection) {
    sections[currentSection] = currentContent.join('\n').trim();
  }

  // Convert to structured data
  const data: DaemonData = {
    about: sections.about,
    mission: sections.mission,
    telos: sections.telos,
    current_location: sections.current_location,
    last_updated: new Date().toISOString()
  };

  // Parse list sections (lines starting with -)
  const listSections = [
    'preferences', 'daily_routine', 'favorite_books',
    'favorite_movies', 'favorite_podcasts', 'predictions'
  ];

  for (const section of listSections) {
    if (sections[section]) {
      const items = sections[section]
        .split('\n')
        .filter(line => line.trim().startsWith('-'))
        .map(line => line.trim().slice(1).trim());
      if (items.length > 0) {
        (data as any)[section] = items;
      }
    }
  }

  return data;
}

/**
 * Load daemon.md from bundled file
 */
function loadDaemonData(): DaemonData {
  try {
    // In Lambda, files are extracted to /var/task/
    // Try multiple paths in order of preference
    const possiblePaths = [
      process.env.DAEMON_MD_PATH,
      '/var/task/daemon.md',
      join(process.cwd(), 'daemon.md'),
      './daemon.md'
    ].filter(Boolean) as string[];

    let content: string | null = null;
    for (const daemonMdPath of possiblePaths) {
      try {
        content = readFileSync(daemonMdPath, 'utf-8');
        console.log(`Successfully loaded daemon.md from: ${daemonMdPath}`);
        break;
      } catch (err) {
        // Try next path
        continue;
      }
    }

    if (!content) {
      throw new Error('Could not find daemon.md in any expected location');
    }

    return parseDaemonMd(content);
  } catch (error) {
    console.error('Failed to load daemon.md:', error);
    return { last_updated: new Date().toISOString() };
  }
}

/**
 * MCP Tools - JSON-RPC 2.0 compatible
 */
const tools = [
  {
    name: 'get_about',
    description: 'Get information about Rick Rezinas',
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_mission',
    description: "Get Rick's mission statement",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_telos',
    description: "Get Rick's TELOS framework (Problems, Missions, Goals)",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_current_location',
    description: "Get Rick's current location",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_preferences',
    description: "Get Rick's preferences and work style",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_daily_routine',
    description: "Get Rick's daily routine",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_favorite_books',
    description: "Get Rick's favorite books",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_favorite_movies',
    description: "Get Rick's favorite movies",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_favorite_podcasts',
    description: "Get Rick's favorite podcasts",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_predictions',
    description: "Get Rick's predictions about the future",
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_all',
    description: 'Get all daemon data',
    inputSchema: { type: 'object', properties: {} }
  }
];

/**
 * Handle tool calls
 */
function handleToolCall(toolName: string, data: DaemonData): any {
  const fieldMap: { [key: string]: keyof DaemonData } = {
    'get_about': 'about',
    'get_mission': 'mission',
    'get_telos': 'telos',
    'get_current_location': 'current_location',
    'get_preferences': 'preferences',
    'get_daily_routine': 'daily_routine',
    'get_favorite_books': 'favorite_books',
    'get_favorite_movies': 'favorite_movies',
    'get_favorite_podcasts': 'favorite_podcasts',
    'get_predictions': 'predictions'
  };

  if (toolName === 'get_all') {
    return JSON.stringify(data, null, 2);
  }

  const field = fieldMap[toolName];
  if (field && data[field]) {
    const value = data[field];
    return Array.isArray(value) ? value.join('\n') : value;
  }

  return 'No data available';
}

/**
 * Lambda handler for API Gateway
 */
export const handler = async (event: any) => {
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      },
      body: ''
    };
  }

  try {
    const daemonData = loadDaemonData();

    // Parse JSON-RPC request
    const body = JSON.parse(event.body || '{}');
    const { jsonrpc, method, params, id } = body;

    // Handle tools/list
    if (method === 'tools/list') {
      return {
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
          jsonrpc: '2.0',
          result: { tools },
          id
        })
      };
    }

    // Handle tools/call
    if (method === 'tools/call') {
      const toolName = params?.name;
      const result = handleToolCall(toolName, daemonData);

      return {
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
          jsonrpc: '2.0',
          result: {
            content: [{ type: 'text', text: result }]
          },
          id
        })
      };
    }

    // Unknown method
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        error: { code: -32601, message: 'Method not found' },
        id
      })
    };

  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        error: { code: -32603, message: 'Internal error' },
        id: null
      })
    };
  }
};
