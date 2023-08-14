# Aelin Etherscan Guide

### This guide will help you claim a share of the Aelin treasury distribution or your assets from Aelin pools and Upfront deals via Etherscan

There are 5 main sections in this document

1. The steps and contracts needed to claim a share of the treasury for AELIN holders.
2. A list of Upfront deal contracts
3. How to claim your assets from Upfront deal contracts
4. A list of Aelin pool contracts
5. How to claim your assets from Aelin pool contracts

## <u>Section 1: Treasury claim instructions</u>

**Contracts**:<br>

1. Claiming NFT Minting contract - https://optimistic.etherscan.io/address/<TBD><br>

2. AELIN token contract - https://optimistic.etherscan.io/address/0x61baadcf22d2565b0f471b291c475db5555e0b76<br>

3. Treasury exchange contract - https://optimistic.etherscan.io/address/<TBD><br>

**Steps**:<br>

1. To retrieve your share of treasury assets you must first mint a NFT agreeing to a waiver. Go to the “Claiming NFT Minting contract” (see #1 above) and call the “mint()” method from the address you will claim treasury funds with using no arguments.

2. Go to the “AELIN token contract” (see #2 above) and call the “approve()” method, passing in the “Treasury exchange contract” address as the “spender” and the full balance of tokens you want to exchange as the “amount (uint256)”. Note to get the correct “amount (uint256)” to pass into this field, simply read the “balanceOf” method on the same “AELIN token contract”, passing in your address. Take the value you see here in your balance and paste it into the “amount (uint256)” field.

3. Go to the “Treasury exchange contract” (see #3 above) and call the “exchangeAndBurn()” method with no arguments.

## <u>Section 2: Upfront deals contract list:</u>

1. LORDS - https://etherscan.io/address/0x946a90c103336b7d06ee1d1764c7c89aacaecb1a

2. Kwenta - https://etherscan.io/address/0x21f4f88a95f656ef4ee1ea107569b3b38cf8daef

3. Thalon Community - https://etherscan.io/address/0x89ff4fbec2081079fa9fa5064ce1c39203165821

4. Thalon x Ethlizards - https://etherscan.io/address/0xc4b35b8bb40368996add8bfc954e3f16579ae82b

5. Halls of Olympia - https://arbiscan.io/address/0xd5541dad40ee8e9357606e409d9d3530c0696ede

6. Kwenta token distribution - https://etherscan.io/address/0x21f4f88a95f656ef4ee1ea107569b3b38cf8daef

7. Ethlizards $LIZ Pre-seed - https://etherscan.io/address/0x00917e8b4a32179b9b6c97880befa111ecb4bf76

8. aiPx presale - https://arbiscan.io/address/0xe10616e9c424463b121c146bfdd9b458f1a049db

9. Influence - Prepare for Launch - https://etherscan.io/address/0x36e8031e2843f3ce873bd66b3915e1e624e6da31

10. Metagates - https://arbiscan.io/address/0x7686b2a7141814d8e119ebbdf506b517b2d63b73

11. Yodus - https://arbiscan.io/address/0x80e52dfb37937bf8c51a21076b75c0dfbf234c65

12. Conjury Mint - https://arbiscan.io/address/0x259f2af9dcc1c944f16280ae1cda5d3ead217d29

## <u>Section 3: Upfront deal claim instructions</u>

**Investors in upfront deals**:<br>

1. First, go to the read method “purchaseTokensPerUser()” and pass in your address as the argument. If this shows a value you have participated in the pool. To claim your tokens, you need to call the “purchaserClaim()” method with no arguments and then “claimUnderlying()” method with no arguments.

**Holders in upfront deals**:<br>

1. If you have not claimed your purchase tokens or retrieved your unsold deal tokens, call the “holderClaim()” method with no arguments

**Sponsors in upfront deals**:<br>

1. If you have not claimed your sponsor tokens, call the “sponsorClaim()” method with no arguments and then “claimUnderlying()” method with no arguments.

## <u>Section 4: Aelin pools contract list:</u>

1. Aelin Treasury Pool - https://optimistic.etherscan.io/address/0xe361ac500fc1d91d49e2c0204963f2cadbcaf67a (pool) https://optimistic.etherscan.io/address/0xf1633b222837fe51000ea78923f09ca9b35003f7 (deal)

2. Ethlizards Muse - https://etherscan.io/address/0x576c9fb6c46abb24530cea6b7eb51277196575ea (pool) https://etherscan.io/address/0xeBDd14E91832b2394157296F9e9CD1705AB21A81 (deal)

3. Muse Group DAO - https://optimistic.etherscan.io/address/0xc7bbd38d1ae4a4aa4bf0d0e7b061b1bb858b0d09 (pool)
   https://optimistic.etherscan.io/address/0x372454ad3f8818dfeda758d2d03011170346635f (deal)

4. Daegens One - https://optimistic.etherscan.io/address/0x95b1ac35d106879923e140c9e9581e224ee3e041 (pool)
   https://optimistic.etherscan.io/address/0xaba9bcad214677c5ec2219e14ef79eafa6e35d2e (deal)

5. Kwenta DAO - https://optimistic.etherscan.io/address/0x20369baa917bd1867bdafc24d72458ac777c9a2c (pool)
   https://optimistic.etherscan.io/address/0xe733372b61406bb3de8178fd3fc172155176689a (deal)

6. Nukevaults dot com - https://optimistic.etherscan.io/address/0xba7f5ab831bfcb7a9a56aab5e293cde5d06393a1 (pool)
   https://optimistic.etherscan.io/address/0x2ce7245ee4737ee43e499616260b19784e3ac747 (deal)

7. Nukevaults dot com - https://optimistic.etherscan.io/address/0x44e2b34e4ab4042652410d44f43af4c379e1bcba (pool)
   https://optimistic.etherscan.io/address/0xa0513d25b6b96bae48bfe84f6e3e5725bd278e15 (deal)

8. Seldon2 - https://optimistic.etherscan.io/address/0xabab6d9dd92645789d52fcb5c4988b7ab8d3e4ca (pool)
   https://optimistic.etherscan.io/address/0x00cc3b9335f8ba0b25262676315d239a86ae724f (deal)

9. Aelin Pool - https://optimistic.etherscan.io/address/0x97fc4e0ce415ef922b08f4725a0fa197d7fdbec3 (pool) (deal irrelevant - was airdropped as a new token)

10. Lode Community Fundraiser - https://etherscan.io/address/0x978a2e2a24b14a04e56a19336740be8bcd69808d (pool)
    https://etherscan.io/address/0x29163CC49aab9838Ac95771D20571B9521BE9860 (deal)

11. esBFR OTC Deal - https://arbiscan.io/address/0x08703a9167a05c99eeb7f9c523a2b073fbc0f28e (pool)
    https://arbiscan.io/address/0x37428fe8eb276774d2ea1d225956034d9e3d5550 (deal)

12. Lodestar Finance FundraiserLodestar Finance Fundraiser - https://arbiscan.io/address/0xedc4ea7043fb6b1d3f9c5732abd4d3aa37269646 (pool)
    https://arbiscan.io/address/0xe2538a84bdc7d34c9ee7f89c835ce78f07d816d5 (deal)

## <u>Section 5: Aelin pool claim instructions</u>

**Investors in Aelin pools**:<br>

1. First, check if you have a balance in the pool by calling the read method “balanceOf()” using your address. If this number is greater than 0, it means you deposited funds into an Aelin pool but never accepted the deal. To retrieve your funds, you should call the “withdrawMaxFromPool()” method with no arguments.

2. You can check if you have claimable tokens by calling the read method `claimableTokens()” with your address as the argument. To vest your tokens in a deal you have accepted, call the “claim()” method with no arguments.

**Holders of Aelin pools**:<br>

1. If there is a balance of your deal tokens in the Aelin deal contract, call the “withdrawExpiry()” method with no arguments to claim your unaccepted deal tokens.

**Sponsors of Aelin pools**:<br>

1. You can check if you have claimable tokens by calling the read method `claimableTokens()” with your address as the argument. If so, vest your tokens in a deal you have sponsored by calling the “claim()” method with no arguments.
