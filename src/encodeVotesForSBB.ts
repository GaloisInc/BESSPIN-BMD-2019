import * as base64js from 'base64-js'
import {
  Candidate,
  CandidateContest,
  // YesNoContest,
  CandidateVote,
  Contests,
  Vote,
  VotesDict,
  // YesNoVote,
  Contest,
} from './config/types'

const TIMESTAMP_PADDING = '0000000' // 7 binary string 0's to prepend to the 41 bit binary string that is the current unix time in milliseconds so that the timestamp becomes a clean 6 bytes
const zeroIV = new Uint8Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
const TIMEOUT_MILLISECONDS = 10000
const SEPERATOR = '+'

function isCandidateVote(vote: Vote): vote is CandidateVote {
  return Array.isArray(vote)
}

// function isYesNoVote(vote: Vote): vote is YesNoVote {
//   return vote === 'yes' || vote === 'no'
// }

function isCandidateContest(contest: Contest): contest is CandidateContest {
  return contest.type === 'candidate'
}

// function isYesNoContest(contest: Contest): contest is YesNoContest {
//   return contest.type === 'yesno'
// }

function candidateWasVotedFor(queryCandidate: Candidate, vote: Vote): boolean {
  if (isCandidateVote(vote)) {
    for (const candidate of vote) {
      if (candidate === queryCandidate) {
        return true
      }
    }
    return false
  } else {
    return false
  }
}

function encodeVotesAsBinaryString(
  contests: Contests,
  votes: VotesDict
): string {
  var binaryString = ''
  for (const contest of contests) {
    if (isCandidateContest(contest)) {
      const vote = votes[contest.id]
      for (const candidate of contest.candidates) {
        if (vote !== undefined) {
          if (candidateWasVotedFor(candidate, vote)) {
            binaryString.concat('1')
          } else {
            binaryString.concat('0')
          }
        } else {
          binaryString.concat('0')
        }
      }
    } else {
      continue
    }
  }
  return binaryString
}

function binarySubstringTo8BitNum(chunk: string): number {
  var tempChunk = chunk
  const paddingLength = 8 - chunk.length
  if (chunk.length < 8) {
    for (let i = 0; i < paddingLength; i++) {
      tempChunk = tempChunk.concat('0')
    }
  }

  return parseInt(chunk, 2)
}

function binaryStringToUint8Array(binaryString: string): Uint8Array {
  var numBytes
  const remainder = binaryString.length % 8
  if (remainder === 0) {
    numBytes = binaryString.length
  } else {
    numBytes = binaryString.length + 1
  }
  var array = new Uint8Array(numBytes)

  for (let i = 0; i < numBytes; i++) {
    array[i] = binarySubstringTo8BitNum(
      binaryString.substring(i * 8, i * 8 + 8)
    )
  }

  return array
}

function combineUint8Arrays(
  array1: Uint8Array,
  array2: Uint8Array
): Uint8Array {
  var newArray = new Uint8Array(array1.length + array2.length)
  newArray.set(array1)
  newArray.set(array2, array1.length)
  return newArray
}

export default async function generateQRCodeString(
  contests: Contests,
  votes: VotesDict,
  timestamp: Date,
  keyData: Uint8Array,
  authKeyData: Uint8Array
): Promise<string> {
  timestamp.setTime(timestamp.getTime() + TIMEOUT_MILLISECONDS)
  var comparisonTimestamp =
    timestamp.getUTCFullYear().toString() +
    SEPERATOR +
    timestamp.getUTCMonth().toString() +
    SEPERATOR +
    timestamp.getUTCDate().toString() +
    SEPERATOR +
    timestamp.getUTCHours().toString() +
    SEPERATOR +
    timestamp.getUTCMinutes().toString()
  const comparisonTimestampArray = new TextEncoder().encode(comparisonTimestamp)

  const votesArray = binaryStringToUint8Array(
    encodeVotesAsBinaryString(contests, votes)
  )
  const timestampArray = binaryStringToUint8Array(
    TIMESTAMP_PADDING + timestamp.getTime().toString(2)
  )
  const dataTimestampArray = combineUint8Arrays(votesArray, timestampArray)

  try {
    const encryptionKey = await crypto.subtle.importKey(
      'raw',
      keyData,
      'AES-CBC',
      false,
      ['encrypt']
    )
    const authKey = await crypto.subtle.importKey(
      'raw',
      authKeyData,
      'AES-CBC',
      false,
      ['encrypt']
    )

    const encryptedArray = new Uint8Array(
      await crypto.subtle.encrypt(
        {
          name: 'AES-CBC',
          iv: zeroIV,
        },
        encryptionKey,
        dataTimestampArray
      )
    )

    const cbcMacInputArray = combineUint8Arrays(
      comparisonTimestampArray,
      encryptedArray
    )

    const cbcMacPadding = new Uint8Array(
      16 - (cbcMacInputArray.length % 16)
    ).fill(0)

    const paddedCbcMacInputArray = combineUint8Arrays(
      cbcMacInputArray,
      cbcMacPadding
    )

    const cbcMacOutputArray = new Uint8Array(
      await crypto.subtle.encrypt(
        {
          name: 'AES-CBC',
          iv: zeroIV,
        },
        authKey,
        paddedCbcMacInputArray
      )
    )

    const cbcMAC = cbcMacOutputArray.subarray(
      cbcMacOutputArray.length - 33,
      cbcMacOutputArray.length - 17
    )

    const base64InputArray = combineUint8Arrays(encryptedArray, cbcMAC)
    const result =
      comparisonTimestamp + SEPERATOR + base64js.fromByteArray(base64InputArray)
    // eslint-disable-next-line no-console
    console.log(result)
    return result
  } catch (err) {
    // eslint-disable-next-line no-console
    console.log('error encrypting array' + err.toString())
    return 'encryption error'
  }
}
