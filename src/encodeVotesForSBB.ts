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
    for (var candidate of vote) {
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
  for (var contest of contests) {
    if (isCandidateContest(contest)) {
      var vote = votes[contest.id]
      for (var candidate of contest.candidates) {
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
  var paddingLength = 8 - chunk.length
  if (chunk.length < 8) {
    for (let i = 0; i < paddingLength; i++) {
      tempChunk = tempChunk.concat('0')
    }
  }

  return parseInt(chunk, 2)
}

function binaryStringToUint8Array(binaryString: string): Uint8Array {
  var numBytes = 0
  var remainder = binaryString.length % 8
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

const zeroIV = new Uint8Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

export default async function generateQRCodeString(
  contests: Contests,
  votes: VotesDict,
  sequenceNumber: number,
  timestamp: number,
  keyData: Uint8Array,
  authKeyData: Uint8Array
): Promise<string> {
  var arrayHoldingTimestamp = binaryStringToUint8Array(timestamp.toString(2))
  var arrayHoldingSeqeuenceNumber = binaryStringToUint8Array(
    sequenceNumber.toString(2)
  )
  var arrayHoldingVotes = binaryStringToUint8Array(
    encodeVotesAsBinaryString(contests, votes)
  )

  var combinedLength =
    arrayHoldingTimestamp.length +
    arrayHoldingSeqeuenceNumber.length +
    arrayHoldingVotes.length

  var combinedArray = new Uint8Array(combinedLength)
  combinedArray.set(arrayHoldingTimestamp, 0)
  combinedArray.set(arrayHoldingSeqeuenceNumber, arrayHoldingTimestamp.length)
  combinedArray.set(
    arrayHoldingVotes,
    arrayHoldingTimestamp.length + arrayHoldingSeqeuenceNumber.length
  )

  try {
    var key = await crypto.subtle.importKey('raw', keyData, 'AES-CBC', false, [
      'encrypt',
    ])

    var encryptedArray = new Uint8Array(
      await crypto.subtle.encrypt(
        {
          name: 'AES-CBC',
          iv: zeroIV,
        },
        key,
        combinedArray
      )
    )

    var authDataArrayLength =
      encryptedArray.length + arrayHoldingTimestamp.length

    var authDataArray = new Uint8Array(authDataArrayLength)
    authDataArray.set(encryptedArray, 0)
    authDataArray.set(arrayHoldingTimestamp, encryptedArray.length)

    var authKey = await crypto.subtle.importKey(
      'raw',
      authKeyData,
      'AES-CBC',
      false,
      ['encrypt']
    )

    var authEncryptedArray = new Uint8Array(
      await crypto.subtle.encrypt(
        {
          name: 'AES-CBC',
          iv: zeroIV,
        },
        authKey,
        authDataArray
      )
    )

    var cbcMAC = authEncryptedArray.subarray(
      authEncryptedArray.length - 17,
      authEncryptedArray.length
    )

    var finalArray = new Uint8Array(authDataArray.length + cbcMAC.length)
    finalArray.set(authDataArray, 0)
    finalArray.set(cbcMAC, authDataArray.length)

    var base64string = base64js.fromByteArray(finalArray)
    return base64string
  } catch (err) {
    // eslint-disable-next-line no-console
    console.log('error encrypting array' + err.toString())
    return 'encryption error'
  }
}
