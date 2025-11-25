// tests/test-repo-manager.js
import { RepoManager } from '../src/services/repo-manager.js';

async function testRepoManager() {
  console.log('🧪 Testing RepoManager...\n');

  const repoManager = new RepoManager();

  try {
    // Test 1: Set repo
    console.log('Test 1: Setting repository...');
    const repoPath = repoManager.setRepo('salesforce-autonomous-dev-system');
    console.log('✅ Repository set:', repoPath);

    // Test 2: Get current branch
    console.log('\nTest 2: Getting current branch...');
    const branch = await repoManager.getCurrentBranch();
    console.log('✅ Current branch:', branch);

    // Test 3: Get status
    console.log('\nTest 3: Getting git status...');
    const status = await repoManager.status();
    console.log('✅ Status:', JSON.stringify(status, null, 2));

    // Test 4: List workspace repos
    console.log('\nTest 4: Listing workspace repos...');
    const repos = await repoManager.listWorkspaceRepos();
    console.log('✅ Found repos:', repos.length);
    repos.forEach(repo => console.log('  -', repo.name));

    // Test 5: Get remotes
    console.log('\nTest 5: Getting remotes...');
    const remotes = await repoManager.getRemotes();
    console.log('✅ Remotes:', JSON.stringify(remotes, null, 2));

    console.log('\n🎉 All RepoManager tests passed!');
    return true;

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error(error.stack);
    return false;
  }
}

testRepoManager().then(success => {
  process.exit(success ? 0 : 1);
});
