import React from 'react'
import { RouteComponentProps } from 'react-router-dom'
import styled from 'styled-components'
import QRCode from '../components/QRCode'
import { findPartyById } from '../utils/find'
import generateQRCodeString from '../encodeVotesForSBB'

import {
  Candidate,
  CandidateContest,
  CandidateVote,
  Contests,
  OptionalYesNoVote,
  Parties,
  YesNoContest,
  YesNoVote,
} from '../config/types'

import Breadcrumbs from '../components/Breadcrumbs'
import Button from '../components/Button'
import ButtonBar from '../components/ButtonBar'
import LinkButton from '../components/LinkButton'
import Main, { MainChild } from '../components/Main'
import Modal from '../components/Modal'
import Prose from '../components/Prose'
import Text from '../components/Text'
import GLOBALS from '../config/globals'
import BallotContext from '../contexts/ballotContext'

const Header = styled.div`
  display: flex;
  flex-direction: row;
  align-items: center;
  border-bottom: 0.2rem solid #000000;
  & > .seal {
    margin: 0.25rem 0;
    width: 1in;
  }
  & h2 {
    margin-bottom: 0;
  }
  & h3 {
    margin-top: 0;
  }
  & > .ballot-header-content {
    flex: 1;
    margin: 0 1rem;
    max-width: 100%;
  }
`

const QRCodeContainer = styled.div`
  display: flex;
  flex-direction: row;
  align-self: flex-end;
  border-bottom: 0;
  max-width: 17%;
  padding: 0.5rem;
  & > div:first-child {
    margin-right: 0.25rem;
  }
  & > div:last-child {
    display: flex;
    flex: 1;
    & > div {
      display: flex;
      flex: 1;
      flex-direction: column;
      align-self: stretch;
      justify-content: space-between;
      font-size: 0.8rem;
      & strong {
        font-size: 1rem;
        word-break: break-word;
      }
    }
  }
`
const Content = styled.div`
  flex: 1;
`
const BallotSelections = styled.div`
  columns: 2;
  column-gap: 2rem;
`
const Contest = styled.div`
  border-bottom: 0.01rem solid #000000;
  padding: 0.5rem 0;
  break-inside: avoid;
  page-break-inside: avoid;
`
const ContestProse = styled(Prose)`
  & > h3 {
    font-size: 0.875em;
    font-weight: 400;
  }
`
const NoSelection = () => (
  <Text italic muted>
    [no selection]
  </Text>
)

const CandidateContestResult = ({
  contest,
  parties,
  vote = [],
}: {
  contest: CandidateContest
  parties: Parties
  vote: CandidateVote
}) => {
  const remainingChoices = contest.seats - vote.length
  return vote === undefined || vote.length === 0 ? (
    <NoSelection />
  ) : (
    <React.Fragment>
      {vote.map((candidate: Candidate) => (
        <Text bold key={candidate.id} wordBreak>
          <strong>{candidate.name}</strong>{' '}
          {candidate.partyId &&
            `/ ${findPartyById(parties, candidate.partyId)!.name}`}
          {candidate.isWriteIn && `(write-in)`}
        </Text>
      ))}
      {!!remainingChoices && (
        <Text italic muted>
          [no selection for {remainingChoices} of {contest.seats} choices]
        </Text>
      )}
    </React.Fragment>
  )
}

const YesNoContestResult = (props: {
  contest: YesNoContest
  vote: OptionalYesNoVote
}) =>
  props.vote ? (
    <Text bold wordBreak>
      <strong>
        {GLOBALS.YES_NO_VOTES[props.vote]}{' '}
        {!!props.contest.shortTitle && `on ${props.contest.shortTitle}`}
      </strong>
    </Text>
  ) : (
    <NoSelection />
  )

const keyData = new Uint8Array([
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
  0,
  255,
])

const authKeyData = new Uint8Array([
  70,
  114,
  111,
  109,
  32,
  82,
  117,
  115,
  115,
  105,
  97,
  32,
  119,
  105,
  116,
  104,
  32,
  76,
  111,
  118,
  101,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
])

interface State {
  showConfirmModal: boolean
  qrCodeDataString: string
}

class SummaryPage extends React.Component<RouteComponentProps, State> {
  public static contextType = BallotContext
  public state: State = {
    showConfirmModal: false,
    qrCodeDataString: 'default',
  }
  public componentDidMount = () => {
    window.addEventListener('afterprint', this.resetBallot)

    generateQRCodeString(
      this.context.contests,
      this.context.votes,
      new Date(),
      keyData,
      authKeyData
    ).then(value => {
      this.setState({
        qrCodeDataString: value,
      })
    })
  }
  public componentWillUnmount = () => {
    window.removeEventListener('afterprint', this.resetBallot)
  }
  public resetBallot = () => {
    // setTimeout to prevent a React infinite recursion issue
    window.setTimeout(() => {
      this.context.resetBallot('/cast')
    }, 0)
  }
  public hideConfirm = () => {
    this.setState({ showConfirmModal: false })
  }
  public showConfirm = () => {
    this.setState({ showConfirmModal: true })
  }
  public print = () => {
    this.context.markVoterCardUsed().then((success: boolean) => {
      if (success) {
        window.print()
      }
    })
  }
  public render() {
    const {
      contests,
      election: { parties, title, county, state, date, bmdConfig },
      votes,
    } = this.context
    const { showHelpPage, showSettingsPage } = bmdConfig

    // const encodedVotes: string = encodeVotes(contests, votes)

    return (
      <React.Fragment>
        <Main>
          <MainChild center>
            <Breadcrumbs step={3} />
            <Prose textCenter className="no-print" id="audiofocus">
              <h1 aria-label="Print your official ballot.">
                Print your official ballot
              </h1>
              <Text narrow>
                If you have reviewed your selections and you are done voting,
                you are ready to print your official ballot.
              </Text>
              <span aria-label="First, press the down arrow, then" />
              <Button
                primary
                big
                onClick={this.showConfirm}
                aria-label="Use the select button to print your ballot."
              >
                Print Ballot
              </Button>
            </Prose>
          </MainChild>
        </Main>
        <ButtonBar>
          <div />
          <LinkButton to="/review" id="previous">
            Back
          </LinkButton>
          <div />
          <div />
        </ButtonBar>
        <ButtonBar secondary separatePrimaryButton>
          <div />
          {showHelpPage && <LinkButton to="/help">Help</LinkButton>}
          {showSettingsPage && <LinkButton to="/settings">Settings</LinkButton>}
        </ButtonBar>
        <Modal
          isOpen={this.state.showConfirmModal}
          centerContent
          ariaLabel=""
          content={
            <Prose id="modalaudiofocus">
              <Text center>
                You may not make any changes after you print your ballot.
              </Text>
              <Text center>Do you want to print your ballot?</Text>
              <span aria-label="Use the down arrow to continue." />
            </Prose>
          }
          actions={
            <>
              <Button
                role="link"
                aria-label="Use the select button to print your ballot."
                primary
                onClick={() => {
                  this.print()
                }}
              >
                Yes, print my ballot.
              </Button>
              <Button onClick={this.hideConfirm}>No, go back.</Button>
            </>
          }
        />
        <div aria-hidden="true" className="print-only">
          <Header>
            <Prose className="ballot-header-content">
              <h2>Official Ballot</h2>
              <h3>{title}</h3>
              <p>
                {date}
                <br />
                {county.name}, {state}
              </p>
            </Prose>
            <QRCodeContainer>
              <QRCode value={`${this.state.qrCodeDataString}`} />
            </QRCodeContainer>
          </Header>
          <Content>
            <BallotSelections>
              {(contests as Contests).map(contest => (
                <Contest key={contest.id}>
                  <ContestProse compact>
                    <h3>{contest.title}</h3>
                    {contest.type === 'candidate' && (
                      <CandidateContestResult
                        contest={contest}
                        parties={parties}
                        vote={votes[contest.id] as CandidateVote}
                      />
                    )}
                    {contest.type === 'yesno' && (
                      <YesNoContestResult
                        contest={contest}
                        vote={votes[contest.id] as YesNoVote}
                      />
                    )}
                  </ContestProse>
                </Contest>
              ))}
            </BallotSelections>
          </Content>
        </div>
      </React.Fragment>
    )
  }
}

export default SummaryPage
