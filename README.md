File description:
1) Copier_v2.mq4 - expert to copy orders from one account to another using file system to sync;
2) TickWatcher.mq4 - expert running indefinitely to copy ticks from MT4 terminal to file system;
3) Trader_v2.mq4 - expert that copies oders from one account into file system.

To create a mirror with Richman:
1) MT4 terminal #1:
    - Run TickWatcher.mq4 (for copy ticks into FS - needed by Richman)
    - Copier_v2.mq4 (needed to copy orders created by Richman from FS into MT4)

2) MT4 terminal #2:
    - Copier_v2.mq4 - point to MT4 terminal #1 configured above and set 'ReverseMode=true'
