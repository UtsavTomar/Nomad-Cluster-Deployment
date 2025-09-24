const request = require('supertest');
const app = require('./server');

describe('Hello World API', () => {
  test('GET / should return hello message', async () => {
    const response = await request(app)
      .get('/')
      .expect(200);
    
    expect(response.body).toHaveProperty('message');
    expect(response.body.message).toContain('Hello from Nomad');
  });

  test('GET /health should return health status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);
    
    expect(response.body).toHaveProperty('status', 'healthy');
    expect(response.body).toHaveProperty('timestamp');
    expect(response.body).toHaveProperty('uptime');
  });

  test('GET /api/status should return service status', async () => {
    const response = await request(app)
      .get('/api/status')
      .expect(200);
    
    expect(response.body).toHaveProperty('status', 'running');
    expect(response.body).toHaveProperty('service', 'nomad-hello-world');
  });

  test('GET /api/info should return service info', async () => {
    const response = await request(app)
      .get('/api/info')
      .expect(200);
    
    expect(response.body).toHaveProperty('service', 'nomad-hello-world');
    expect(response.body).toHaveProperty('version');
    expect(response.body).toHaveProperty('description');
    expect(response.body).toHaveProperty('endpoints');
  });

  test('GET /nonexistent should return 404', async () => {
    const response = await request(app)
      .get('/nonexistent')
      .expect(404);
    
    expect(response.body).toHaveProperty('error', 'Not found');
  });
});
