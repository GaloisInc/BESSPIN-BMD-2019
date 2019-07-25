# QR Code Format for SBB

### Wire Format

`comparison-timestamp` ":" `base64-string`

#### where

- `comparison-timestamp`
  - = `year` "+" `month` "+" `day` "+" `hour` "+" `minute`
  - 12 bytes
- `year`
  - = 4 ascii characters representing the year
  - 4 bytes
- `month`
  - = 2 ascii characters representing the month
  - 2 bytes
- `day`
  - = 2 ascii characters representing the day
  - 2 bytes
- `hour`
  - = 2 ascii characters representing the hour (24 hour clock)
  - 2 bytes
- `minute`
  - 2 ascii characters representing the minute
  - 2 bytes
- `base64-string`
  - = base64( `encrypted-block` # `cbc-mac`)
- `encrypted-block`
  - = AES( `votes` # `timestamp` )
  - 16 bytes
- `timestamp`
  - = Unix time in milliseconds as an unsigned integer
  - 6 bytes
- `votes`
  - = a flattened representation of all contests where each candidate is
    represented as a bit in a string of bits that is put into an array and zero
    padded
  - numCandidates /^ 8 number of bytes
- `cbc-mac`
  - = the last AES block of AES( `comparison-timestamp` # `encrypted-block` )
  - `comparison-timestamp` # `encryted-block` is padded out with 0 bytes to fit
    into AES blocks neatly
  - 16 bytes

### Flattened Vote Encoding

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

The encoding would be a binary array where each candidate is represented by a
bit in the array

```
[Alice, Bob, Charles, David, Earl, Frank, George, Harry]
```

where a sample concrete ballot that votes for Bob and Frank would be:

```
[0, 1, 0, 0, 0, 1, 0, 0]
```
