const fs = require('fs');
const text = fs.readFileSync('longest_spec.md', 'utf8');

function extractCodeBlocks(text, startHeader, endHeader) {
  const startIndex = text.indexOf(startHeader);
  if (startIndex === -1) return '';
  const endIndex = endHeader ? text.indexOf(endHeader, startIndex) : text.length;
  const slice = text.substring(startIndex, endIndex);
  
  const regex = /```sql\n([\s\S]*?)```/g;
  let matches = [];
  let match;
  while ((match = regex.exec(slice)) !== null) {
    matches.push(match[1]);
  }
  return matches.join('\n\n');
}

const plan = [
  { name: '20260718000001_extensions.sql', content: extractCodeBlocks(text, '### 3.1 Extensions', '### 3.2 Enum Types') },
  { name: '20260718000002_enum_types.sql', content: extractCodeBlocks(text, '### 3.2 Enum Types', '### 3.3 Tables') },
  { name: '20260718000003_tables.sql', content: extractCodeBlocks(text, '### 3.3 Tables', '### 3.4 Role Helper') },
  // Wait, I should probably combine 3.4 and 3.5 into rls since 3.4 is just current_employee_role()
  { name: '20260718000004_rls.sql', content: extractCodeBlocks(text, '### 3.4 Role Helper', '### 3.5 Row-Level Security') + '\n\n' + extractCodeBlocks(text, '### 3.5 Row-Level Security', '### 3.6 Functions') },
  { name: '20260718000005_functions_triggers.sql', content: extractCodeBlocks(text, '### 3.6 Functions', '### 3.7 Views') },
  { name: '20260718000006_views.sql', content: extractCodeBlocks(text, '### 3.7 Views', '### 3.8 Scheduled Jobs') },
  { name: '20260718000007_cron_jobs.sql', content: extractCodeBlocks(text, '### 3.8 Scheduled Jobs', '### 3.9 Seed Data') },
  { name: '20260718000008_seed_data.sql', content: extractCodeBlocks(text, '### 3.9 Seed Data', '## 4.') }
];

plan.forEach(f => {
  fs.writeFileSync('supabase/migrations/' + f.name, f.content);
  console.log('Wrote ' + f.name + ' (' + f.content.length + ' bytes)');
});
