# Demo seed runbook
See scripts/README_seed_demo.md for commands.
Flutter read-path check: catalog shows Midnight Emerald Silk / Nile Gold Cotton / Burgundy Silk Velvet;
details show variants 1m/2m/5m + rating; home hero can feature discounted demo-silk-01.
Cleanup: delete demo users via dashboard Auth (profiles cascade); catalog demo rows: `DELETE FROM products WHERE slug LIKE 'demo-%'` (variants/images/flash cascade).
