module.exports = {
  apps: [{
    name: 'phase2-main',
    script: './src/phase2/main.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production'
    },
    error_file: './logs/phase2-error.log',
    out_file: './logs/phase2-out.log',
    log_file: './logs/phase2-combined.log',
    time: true
  }]
};