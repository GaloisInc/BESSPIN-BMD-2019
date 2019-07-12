# QR Code Format for SBB

base64( `encrypted-block` # `timestamp` # `cbc-mac` )

#### where

- `encrypted-block` = AES( `timestamp` # `votes` )
- `timestamp` = Unix time in milliseconds as a binary number
- `cbc-mac` = the last AES block of AES( `encrypted-block` # `timestamp` )
- `votes` = is a flattened representation of all contests where each candidate
  is represented as a bit in a string of bits that is put into an array and zero
  padded

#### Flattened Vote Encoding

Consider the following election structure:

- President
  - Alice
  - Bob
  - Charles
- Senator
  - David
  - Earl
  - Frank
- Congressman
  - George
  - Harry

The encoding would be a binary array [Alice, Bob, Charles, David, Earl, Frank,
George, Harry] where ballot encoding that votes for Bob, Frank would be: [0, 1,
0, 0, 0, 1, 0, 0]
