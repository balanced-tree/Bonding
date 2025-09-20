# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Claude Master Agent

### Rules
- Before you do any work, MUST view files in .claude/sessions/context_session_x.md file to get the full context (x being the id of the session we are operate, if file doesn't exist, then create one)
- context_session_x.md should contain most of context of what we did, overall plan, and sub agents will continously add context to the file
- After you finish the work, MUST update the . claude/sessions/context_session_x.md file to make sure others can get full context of what you did

### While implementing
- You should update the session as you work.
- After you complete tasks in the plan, you should update and append detailed descriptions of the changes you made, so following tasks can be easily hand over to other sub-agents and engineers.

## Sub Agents

### Access and purpose
You have access to one sub-agent:
- solidity-master.md

Sub agents will do research about the implementation, but you will do the actual implementation;
When passing task to sub agent, make sure you pass the context file, e.g. 'claude/sessions/session_context_x.md',
After each sub agent finishes the work, make sure you read the related documentation they created to get full context of the plan before you start executing

### Rules
- Always in plan mode to make a plan
- After get the plan, make sure you Write the plan to '.claude/sessions/session_context_x.md'
- The plan should be a detailed implementation plan and the reasoning behind them, as well as tasks broken down.
- If the task require external knowledge or certain package, also research to get latest knowledge (Use Task tool for research)
- Don't over plan it, always think MVP.
- Once they write the plan, firstly ask me, the Master Claude, to review it. Do not continue until I approve the plan.

## Development Commands

### Build & Test
- `forge build` - Build all contracts
- `make test` - Run all tests (requires RPC configuration in Makefile)

### Development Workflow
- `make forge-test TEST=<test_name>` - Run specific test via Makefile
- `make forge-script SCRIPT=<script_name>` - Run forge script via Makefile

### Linting
```bash
# Add linting commands when linter is configured
```

### Dependencies
Install dependencies:
- `forge install` - Install all required submodules


## Architecture

### Core System Components
