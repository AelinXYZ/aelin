## NOTE VestAMM workflow notes

- step 1 is create the vest amm and pass in the price and the amount of base tokens you want to deposit in phase 2
  for a liquidity launch price will remain the same throughout the process
  for a liquidity growth round the price will shift throughout the process
  the amount of base tokens the protocol selects will set the max amount of investment tokens that can be accepted

NOTE on multiple vesting schedules

in step 1 the protocol may select up to 5 different vesting schedules for users and the amount of LP tokens they will
get for participating in each round. NOTE that multiple vesting schedules doesn't affect the pricing each user gets
instead for a longer vesting schedule you should get more of the LP tokens than people entering with less of a lockup
also NOTE there is a benefit to having multiple vesting schedules which is that investors dont all unlock at once.

500 ABC tokens being matched against 2500 sUSD across 4 buckets
ABC is 5 sUSD per token
protocol selects 50/50 pool on Balancer
protocol provides half the capital. Investors provide the other half.
the protocol only passes in the number of ABC tokens per schedule. not the amount of sUSD.
The sUSD amount is taken from the pricing which is either passed in for a liquidity or read from the AMM for a liquidity growth.
schedule 1 - 100 ABC tokens match 500 sUSD in this bucket (3 month cliff, 3 month linear vest). Investors get 60% of LP tokens.
schedule 2 - 100 ABC tokens match 500 sUSD in this bucket (3 month cliff, 6 month linear vest). Investors get 70% of LP tokens.
schedule 3 - 100 ABC tokens match 500 sUSD in this bucket (6 month cliff, 6 month linear vest). Investors get 80% of LP tokens.
schedule 4 - 200 ABC tokens match 1000 sUSD in this bucket (6 month cliff, 18 month linear vest). Investors get 100% of LP tokens.

deallocation rules
all buckets must be full and are sold on a FCFS basis
optionally, a protocol may allow buckets to be oversubscribed only after all buckets are full

- step 2 is fund the rewards (base and single sided rewards)
- step 3 is for investors to accept the deal (deposit window for this period)
- step 4 is to provide liquidity (could be at any price in a liquidity growth round - liquidity providing window for this too)
- step 5 is for claiming of vesting schedules

e.g. liquidity launch round
step 1 pass in the price, Price 5 sUSD/ABC when you create the pool
step 1 you set the amount of ABC tokens to 1M.
what this means is that you are not going to accept more than $5M sUSD (max sUSD accepted for the deal)

e.g. liquidity growth round
step 1 do not pass in the price, you read it from the AMM. Price 5 sUSD/ABC when you create the pool
step 1 you set the amount of ABC tokens to 1M.
what this means is that you are not going to accept more than $5M sUSD (max sUSD accepted for the deal)

step 2 is the same for both, the protocol funds 1M ABC tokens in each case

step 3 is the same for both, investors deposit sUSD (can be capped at 5M or uncapped where they get deallocated e.g. 10M sUSD)

step 4 for liquidity launch round you just create the pool and deposit it at the fixed price.
if there is excess sUSD you give everyone back their deallocated amount

For the examples below let's make the simple assumption 5M sUSD was deposited and capped at that amount

step 4 for liquidity growth round you just create the pool and deposit it at the current price.
outcome 1: price is lower than when the pool started (1 ABC is now 2.5 sUSD)
1M ABC tokens in the contract and 5M sUSD but when you go to LP you can only match 2.5M sUSD
protocol has 2 choices
choice 1: just match 1M ABC against 2.5M sUSD and return the 2.5M sUSD extra to investors
choice 2: deposit more ABC tokens up to an additional 1M so they can match more sUSD. 2M ABC/ 5M sUSD is deposited
outcome 2: price is the same (1 ABC is 5 sUSD)
see liquidity launch. you LP 1M ABC against 5M sUSD and there are no changes to the original ratios
outcome 3: price has shifted higher (1 ABC is 10 sUSD)
when you go to LP you match 0.5M ABC against 5M sUSD and the additional 0.5M ABC tokens will be sent to the investors
in the pool as a single sided reward. this extra 0.5M ABC will offset the investors against IL. Generally, the reward
is sufficient to cover extremely large IL after a price run up.

step 5 investors claim their tokens when the vesting is done

phase 0 is deposit all tokens from holders (no deadlines). mostly done
phase 1 is deposit investment tokens from depositors (deposit expiry). mostly done
phase 2 is deposit LP tokens to finalize the deal. TODO.
phase 2 NOTE: Liquidity Launch Pools and Liquidity Growth Pools
//

- we create the pool with the given ratios and tokens (only for liquidity launch)
- we deposit the LP tokens
- we set the amount of LP tokens deposited
- we set the time when the LP tokens were deposited
  //
- e.g.you have 3 buckets with 10, 20 and 30 ABC tokens each with longer vesting schedules than the previous bucket
  in addition to the ABC there is OP single sided rewards of 10, 20 and 30 for each bucket as well
  ABC is raising at a price of 10 sUSD so you have 100 sUSD, 200 sUSD and 300 sUSD as the max amount of investment tokens per bucket
  so if bucket 1 only fills up 50%, bucket 2 fills up 75% and bucket 3 fills to the cap
  assuming this is a liquidity launch for ABC then the logic is when we go to deposit LP tokens
  first we will create the pool, then we will deposit 5 ABC (50% _ 10) from bucket 1, 15 ABC from bucket 2 (75% _ 20), and 30 ABC from bucket 3 (100% \* 30)
  in total this is 5 + 15 + 30 = 50 AELIN. and we also raised 500 sUSD. so we are going to LP 50 AELIN/500 sUSD and we need to
  note the address of the LP tokens we get back as well as how many LP tokens we get back and the time when we deposited (save to storage)
  //
- the more complicated phase is a liquidity growth phase
- in this growth phase the prices are shifting
- price at start of pool is 10 sUSD per ABC
- e.g.you have 3 buckets with 10, 20 and 30 ABC tokens each fills up 50%, 75%, and 100% based on the price at the start of the pool
- the price of ABC between the start of the pool and the time we LP is irrelevant.
- we only care about the price when the pool starts as well as the price when we go to LP
- if the price of ABC goes down to $5 then...
  - the maximum amount of sUSD we can accept is $50, $100, $150
  - but there is $50, $150 and $300 in each bucket. this was the maximum amount based on the starting price
  - 2 issues. first
  - NOTE: since the price went down investors are happy because they get more ABC tokens for the same amount of sUSD
  - NOTE we might want to let the protocol deposit extra tokens on their side in order to use the full amount of sUSD
    - for bucket 1 if the price is 5 sUSD now even though the price was $10 and we only filled up half the pool we
    - actually have enough ABC to match all the sUSD now 50 sUSD/ 10 ABC. now the investors get double the amount of ABC. there is no problem
    - for bucket 3 if the price 5 sUSD the total 300/ 60 ABC is the max but we only have 30 ABC in the contract.
    - ideally the protocol can decide to deposit an extra 30 ABC here or we can force them to only take half the sUSD and return the rest
    - option 1 is you take 150/30 or you add more ABC and do 300/60. TBD
- if the price of ABC stays flat at $10 then the logic is exact same as a liquidity launch (will basically never happen)...
  - the maximum amount of sUSD we can accept is $100, $200, $300
- if the price of ABC goes up to $20 then...
  - the maximum amount of sUSD we can accept is $100, $200, $300
  - however the amounts in the pool are $50, $150 and $300
  - for bucket 1 we want to LP (50 sUSD/ 2.5 ABC).
    if the price was $10 the investors would have had more ABC in their LP. 50 sUSD/ 5 ABC
    so they will get at least 5 ABC tokens as a reward (LP or single sided)
    however when the price goes up they get less than 5 ABC. so we give them the extra as single sided rewards
    the math for this is:
    total allocation to bucket 1 (10 ABC) - (percent of bucket 1 empty (50%) \* total allocation to bucket 1 (10 ABC)) = 10 - 5 = 5 ABC - the amount of ABC in the LP (2.5) = 5 - 2.5 = 2.5 AELIN single sided rewards
    2.5 ABC will be added as single rewards for this bucket. 5 ABC will go back to the protocol
  - for bucket 2 we want to LP (150 sUSD/ 7.5 ABC).
    if the price was $10 the investors would have had more ABC in their LP. 150 sUSD/ 15 ABC
    so they will get at least 15 ABC tokens as a reward (LP or single sided) and 5 ABC tokens are going back to the protocol
    however when the price goes up they get less than 15 ABC. so we give them the extra as single sided rewards
    the math for this is:
    total allocation to bucket 2 (20 ABC) - (percent of bucket 1 empty (25%) \* total allocation to bucket 1 (20 ABC)) = 20 - 5 = 15 ABC - the amount of ABC in the LP (7.5) = 15 - 7.5 = 7.5 AELIN single sided rewards
    7.5 ABC will be added as single rewards for this bucket. 5 ABC will go back to the protocol
  - for bucket 3 we want to LP (300 sUSD/ 15 ABC).
    if the price was $10 the investors would have had more ABC in their LP. 300 sUSD/ 30 ABC
    so they will get at least 30 ABC tokens as a reward (LP or single sided) and 0 ABC tokens are going back to the protocol since the bucket is full
    however when the price goes up they get less than 30 ABC. so we give them the extra as single sided rewards
    the math for this is:
    total allocation to bucket 3 (30 ABC) - (percent of bucket 1 empty (0%) \* total allocation to bucket 1 (30 ABC)) = 30 - 0 = 30 ABC - the amount of ABC in the LP (15) = 30 - 15 = 15 AELIN single sided rewards
    7.5 ABC will be added as single rewards for this bucket. 5 ABC will go back to the protocol
    phase 3 is just claiming. mostly done
    also phase 3/ phase 4 is VestAMMMultiRewards.sol where only the mainHolder can emit new rewards to locked LPs. TODO.
    to create the pool and deposit assets after phase 0 ends
    TODO create a struct here that should cover every AMM. If needed to support more add a second struct

NOTE here are the steps that need to happen in a liquidity launch step by step
first you create the pool (in library)
then you deposit the right amount of (sUSD/ABC). the price is fixed
so its all the protocol tokens or just as much as can be paired against the number of investment tokens
across all buckets or the total amount deposited, whichever is smaller
we need to capture what the LP token that we used is and save the address and amount of LP tokens we get back
we also need to capture the timestamp of the block when we LP'd
NOTE that we need to figure out within each bucket if the bucket is not full
then we need to refund the single sided rewards and protocol tokens for that bucket based on how much was not filled
e.g. bucket 1 is 100 ABC and the price is 10 sUSD totalling 1000 sUSD
but the bucket only gets 600 sUSD instead of 1000, then each holder gets back 40%
deploy pool needs to create the pool and deposit the LP tokens and it needs to give us back a few things
TODO fix the first argument to use a new variable that combines the fields we have already stored related to the pool

liquidity growth is going to be more complex than liquidity launch since the price will shift
the pool has already been created so no need for that first
first we need to determine if the price ratio between the two assets have changed since we
created the vAMM. we read this initial price off the pool in the initialize function
if the price goes up, down or stays the same the logic will change 2. if the price goes up
we need to LP the maximum amount of ABC tokens that we can against the available investment tokens
whatever is left of ABC tokens in a given bucket over needs to be given as single sided rewards to that
specific bucket NOTE that if a bucket is not full we need to also make sure the protocol can take their tokens
back and only the portion of the extra will be given as single sided rewards. we need some math for this.
basically we take how many protocol tokens you would get if the price never shifted to see what amount goes
back to the protocol and what amount goes to single sided rewards. 3. if the price goes down
we need to add a view that tells the holder how many extra tokens they can deposit to make up for the difference
they can invest from 0 extra up to that full amount. this gives the sUSD investors more ABC tokens vs the price
at initilization.
step 1 is add liquidity
