/* eslint-disable no-console */
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
const SEPARATOR = '+'
const B64_SEPARATOR = ':'

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
  console.log('contests=', contests)
  console.log('votes=', votes)
  var binaryString = ''
  for (var contest of contests) {
    console.log('var contest=', contest)
    if (isCandidateContest(contest)) {
      console.log('isCandidateContest=', isCandidateContest(contest))
      var vote = votes[contest.id]
      console.log('vote=', vote)
      for (var candidate of contest.candidates) {
        console.log('candidate=', candidate)
        if (vote !== undefined) {
          console.log('vote !== undefined')
          if (candidateWasVotedFor(candidate, vote)) {
            console.log('candidate was voted for')
            binaryString = binaryString.concat('1')
          } else {
            console.log('candidate was not voted for')
            binaryString = binaryString.concat('0')
          }
        } else {
          console.log('vote === undefined')
          binaryString = binaryString.concat('0')
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
    numBytes = binaryString.length / 8
  } else {
    numBytes = binaryString.length / 8 + 1
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

function padForAES(array: Uint8Array): Uint8Array {
  if (array.length % 16 !== 0) {
    const padding = new Uint8Array(16 - (array.length % 16)).fill(0)
    const result = combineUint8Arrays(array, padding)
    return result
  } else {
    return array
  }
}

function twoDigitNumString(number: number): string {
  return ('0' + number.toString()).slice(-2)
}

function uint8ArrayToB64(array: Uint8Array): string {
  const rawString = base64js.fromByteArray(array)
  const temp = rawString.replace(/\//gi, '_')
  return temp.replace(/\+/gi, '-')
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
    SEPARATOR +
    twoDigitNumString(timestamp.getUTCMonth()) +
    SEPARATOR +
    twoDigitNumString(timestamp.getUTCDate()) +
    SEPARATOR +
    twoDigitNumString(timestamp.getUTCHours()) +
    SEPARATOR +
    twoDigitNumString(timestamp.getUTCMinutes())
  const comparisonTimestampArray = new TextEncoder().encode(comparisonTimestamp)
  console.log('comparisonTimestampArray=', comparisonTimestampArray)
  console.log(
    'decoded comparisonTimestampArray=',
    new TextDecoder().decode(comparisonTimestampArray)
  )

  console.log('votes bin string=', encodeVotesAsBinaryString(contests, votes))
  const votesArray = binaryStringToUint8Array(
    encodeVotesAsBinaryString(contests, votes)
  )
  console.log('votesArray=', votesArray)
  const timestampArray = binaryStringToUint8Array(
    TIMESTAMP_PADDING + timestamp.getTime().toString(2)
  )
  console.log('timestampArray=', timestampArray)
  const dataTimestampArray = padForAES(
    combineUint8Arrays(votesArray, timestampArray)
  )
  console.log('dataTimestampArray=', dataTimestampArray)

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

    const encryptedArrayWithPadding = new Uint8Array(
      await crypto.subtle.encrypt(
        {
          name: 'AES-CBC',
          iv: zeroIV,
        },
        encryptionKey,
        dataTimestampArray
      )
    )
    console.log('encryptedArrayWithPadding=', encryptedArrayWithPadding)

    const encryptedArray = encryptedArrayWithPadding.subarray(
      0,
      encryptedArrayWithPadding.length - 16
    )
    console.log('encryptedArray=', encryptedArray)

    const cbcMacInputArray = combineUint8Arrays(
      comparisonTimestampArray,
      encryptedArray
    )
    console.log('cbcMacInputArray=', cbcMacInputArray)

    const paddedCbcMacInputArray = padForAES(cbcMacInputArray)
    console.log('paddedCbcMacInputArray=', paddedCbcMacInputArray)

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
    console.log('cbcMacOutputArray=', cbcMacOutputArray)

    const cbcMAC = cbcMacOutputArray.subarray(
      cbcMacOutputArray.length - 32,
      cbcMacOutputArray.length - 16
    )
    console.log('cbcMAC=', cbcMAC)

    const base64InputArray = combineUint8Arrays(encryptedArray, cbcMAC)
    const result =
      comparisonTimestamp + B64_SEPARATOR + uint8ArrayToB64(base64InputArray)

    console.log(result)
    return result
  } catch (err) {
    console.log('error encrypting array' + err.toString())
    return 'encryption error'
  }
}
