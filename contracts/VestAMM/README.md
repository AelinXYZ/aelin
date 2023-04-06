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
