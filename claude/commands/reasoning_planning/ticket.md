You will receive a role and a job description that defines your specialized expertise and mission. Your task is to systematically scan a codebase from the perspective of this role, identifying issues and building a cumulative report across multiple passes.
You will receive two critical inputs before beginning your work:
Current Report: Located at .claude/tickets/{role}_report.md, this file contains all findings discovered so far by previous scans in your role. If this file does not exist, you are running the first scan and should create it. If it exists, read it completely before starting—this represents the cumulative knowledge of all previous scan passes and you must not duplicate work already documented here.
Work History: Located at .claude/history/{role}_history.txt, this file contains a chronological log of what specific areas, files, patterns, or issues have already been examined in previous passes. Read this file to understand what ground has already been covered so you avoid re-scanning the same code or re-reporting the same findings.
Scanning Strategy: Start by reviewing what's already in your current report and work history to understand the landscape. Then systematically examine the codebase looking for new findings that haven't been documented yet. You might scan different files, different patterns, different layers of the architecture, or approach from different angles than previous passes. Use your judgment about where to focus—go where you're most likely to find undiscovered issues within your specialty. You don't need to re-examine areas that have been thoroughly covered unless you have reason to believe previous passes missed something important.
Reporting Format: When you discover new findings, append them to .claude/tickets/{role}_report.md in whatever structure makes sense for your role—this might be grouped by severity, by file/module, by issue type, or any organization that serves clarity. Each finding should include:
Clear identification of what the issue is
Location (file paths, functions, components, or architectural layers)
Explanation of why this matters (impact, risk, or opportunity cost)
Severity or priority assessment if relevant
Recommended remediation or improvement approach
Any relevant context or dependencies
Work History Tracking: After completing your scan, update .claude/tickets/{role}_history.txt with a timestamped entry documenting what you examined in this pass, what areas of the codebase you covered, what patterns you looked for, and a summary of how many new findings were added to the report. This creates a clear record preventing future passes from duplicating the same analysis.
Format for history entries:
[YYYY-MM-DD HH:MM] Scan Pass {N}
Examined: [specific files, directories, patterns, or architectural layers covered]
Focus: [what you were specifically looking for this pass]
Findings Added: [count and brief summary]
Coverage Notes: [any areas not yet examined or that need deeper investigation]
Continuous Operation: This prompt is designed to be run multiple times. Each time it runs, you read the existing report and history, then continue the work by scanning areas not yet covered or examining from angles not yet explored. The current report acts as your cumulative knowledge base—you're always building on previous work, never starting from scratch. Run this prompt repeatedly until the codebase has been comprehensively examined from your role's perspective and the report represents a complete audit of your specialty domain.
