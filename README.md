# Comm-Log Send Reconciliation

This repository contains my solution for the Finance `target_base` metric reconciliation assignment. The goal was to investigate the raw campaign and communication logs to figure out how the final target base of 22 is actually calculated, starting from a naive count.

## Folder structure

```
data/                     -> raw data given for the assignment (unchanged)
  comm_log.db
  campaign.csv
  communication_log.csv

queries/
  exploration.sql          -> queries used while figuring things out
  reconciliation.sql       -> final query, returns 22

solution.py                -> runs reconciliation.sql and prints the result
Reconciliation.md           -> this file
README.md                  -> data dictionary provided with the assignment
```

## How to run it

Using sqlite3, from the repo root:

```
sqlite3 data/comm_log.db < queries/reconciliation.sql
```

Or using Python:

```
python solution.py
```

`solution.py` reads `queries/reconciliation.sql` and runs it against `data/comm_log.db`, so run it from the repo root, not from inside `queries/`.

Both return **22**.

### 1. Reconciliation Bridge

Here is the step-by-step breakdown of how I investigated the data and reached the final number.

| Step | Description                 | Result | Reason                                                                                                                                                                                                                                   |
| :--- | :-------------------------- | :----- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0    | Naive count                 | 30     | Starting point: This is the raw row count of every send attempt in the `communication_log` table.                                                                                                                                        |
| 1    | Filter unapproved campaigns | 26     | Campaigns only count if `creation_status` is finalized and `processing_status` is 'processed'. This step removes 4 sends from campaign 9004 because it is still 'approval_awaiting'.                                                     |
| 2    | Deduplicate retry chains    | 22     | A customer targeted multiple times in a retry chain counts only once. Standalone campaigns count every send independently. Grouping by the root campaign dropped 4 duplicate retry sends (3 from the 9001 chain, 1 from the 9201 chain). |

The step-by-step queries behind each row of this table are in `queries/exploration.sql`.

### 2. SQL Query

The final query to reproduce the `target_base` of 22 is in `queries/reconciliation.sql`, runnable directly against `data/comm_log.db`.

Here is how the logic works:

- **`campaign_tree`**: Uses a recursive query to trace every campaign back to its original "root" parent.
- **`eligible_campaigns`**: Filters out any campaigns that haven't passed the approval and processing workflow.
- **`chain_sizes`**: Checks whether a campaign is a standalone (size 1) or part of a retry chain (size > 1).
- **Final SELECT**: Counts standalone logs normally, but uses a `COUNT(DISTINCT...)` on the retry chains to ensure a customer is only counted once per root campaign.

### 3. What surprised me

The thing that initially threw me off was assuming "distinct customer" was the right way to count everywhere. If you just take distinct customers across all eligible campaigns, you get 21, not 22 — because that quietly collapses campaign 9101's two legitimate sends to the same customer (C20) into one, even though there's no retry relationship there at all. It took a closer read of the README to realize that rule only applies inside a retry chain, not everywhere. I also noticed campaign 9004 already has fully delivered send records in `communication_log` even though it's still `approval_awaiting` — so the send pipeline and the approval workflow clearly aren't synced up, which seems worth flagging separately from this exercise.
