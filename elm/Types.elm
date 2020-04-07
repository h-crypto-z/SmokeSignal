module Types exposing (..)

import Browser
import Browser.Navigation
import CommonTypes exposing (..)
import Contracts.SmokeSignal as SSContract
import Dict exposing (Dict)
import Eth.Sentry.Event as EventSentry exposing (EventSentry)
import Eth.Sentry.Tx as TxSentry exposing (TxSentry)
import Eth.Sentry.Wallet as WalletSentry exposing (WalletSentry)
import Eth.Types exposing (Address, Hex, Tx, TxHash, TxReceipt)
import Http
import Time
import TokenValue exposing (TokenValue)
import Url
import UserNotice as UN exposing (UserNotice)
import Wallet


type alias Flags =
    { networkId : Int
    , width : Int
    , height : Int
    , nowInMillis : Int
    }


type alias Model =
    { wallet : Wallet.State
    , now : Time.Posix
    , txSentry : TxSentry Msg
    , eventSentry : EventSentry Msg
    , messages : Dict String Message -- Can't use Hex as a key; Elm is silly with what is and is not comparable
    , miningMessages : Dict String MiningMessage -- key is the txHash of the mining tx
    , showComposeUX : Bool
    , composeUXModel : ComposeUXModel
    , blockTimes : Dict Int Time.Posix
    , showAddress : Maybe PhaceId
    , userNotices : List (UserNotice Msg)
    }


type Msg
    = NoOp
    | Tick Time.Posix
    | EveryFewSeconds
    | WalletStatus (Result String WalletSentry)
    | TxSentryMsg TxSentry.Msg
    | EventSentryMsg EventSentry.Msg
    | MessageLogReceived Eth.Types.Log
    | ShowOrHideAddress PhaceId
    | ConnectToWeb3
    | UnlockDai
    | UnlockMining (Result String TxHash)
    | AllowanceFetched Address (Result Http.Error TokenValue)
    | BalanceFetched Address (Result Http.Error TokenValue)
    | ShowComposeUX Bool
    | MessageInputChanged String
    | DaiInputChanged String
    | DonationCheckboxSet Bool
    | Submit MessageDraft
    | SubmitSigned MessageDraft (Result String TxHash)
    | CheckMiningMessagesStatus
    | MiningMessageStatusResult (Result Http.Error TxReceipt)
    | BlockTimeFetched Int (Result Http.Error Time.Posix)
    | DismissNotice Int
    | ClickHappened


type alias Message =
    { block : Int
    , author : Address
    , burnAmount : TokenValue
    , message : String
    }


type alias MiningMessage =
    { draft : MessageDraft
    , status : MiningMessageStatus
    }


type MiningMessageStatus
    = Mining
    | Failed String


updateMiningMessageByMessageDraft : MessageDraft -> (MiningMessage -> MiningMessage) -> Dict String MiningMessage -> Dict String MiningMessage
updateMiningMessageByMessageDraft draft updateFunc =
    let
        isSameMessage m =
            m.draft == draft
    in
    Dict.map
        (\_ message ->
            if isSameMessage message then
                updateFunc message

            else
                message
        )


type PhaceId
    = MessageAuthor Hex
    | UserMiningMessage TxHash
    | User


type alias ComposeUXModel =
    { message : String
    , daiInput : String
    , donateChecked : Bool
    , miningUnlockTx : Maybe TxHash
    }


updateMessage : String -> ComposeUXModel -> ComposeUXModel
updateMessage message m =
    { m | message = message }


updateDaiInput : String -> ComposeUXModel -> ComposeUXModel
updateDaiInput input m =
    { m | daiInput = input }


updateDonateChecked : Bool -> ComposeUXModel -> ComposeUXModel
updateDonateChecked flag m =
    { m | donateChecked = flag }


updateMiningUnlockTx : Maybe TxHash -> ComposeUXModel -> ComposeUXModel
updateMiningUnlockTx maybeTxHash m =
    { m | miningUnlockTx = maybeTxHash }


type alias CheckedMaybeValidInputs =
    { message : Maybe String
    , burnAndDonateAmount : Maybe (Result String ( TokenValue, TokenValue ))
    }


type alias MessageDraft =
    { author : Address
    , message : String
    , burnAmount : TokenValue
    , donateAmount : TokenValue
    }


validateInputs : ComposeUXModel -> CheckedMaybeValidInputs
validateInputs composeModel =
    { message =
        if composeModel.message == "" then
            Nothing

        else
            Just composeModel.message
    , burnAndDonateAmount =
        validateBurnAmount composeModel.daiInput
            |> Maybe.map
                (Result.map
                    (\burnAmount ->
                        ( burnAmount
                        , if composeModel.donateChecked then
                            TokenValue.div burnAmount 100

                          else
                            TokenValue.zero
                        )
                    )
                )
    }


validateBurnAmount : String -> Maybe (Result String TokenValue)
validateBurnAmount input =
    if input == "" then
        Nothing

    else
        Just
            (TokenValue.fromString input
                |> Result.fromMaybe "Invalid burn amount"
                |> Result.andThen
                    (\tv ->
                        if TokenValue.compare tv TokenValue.zero == GT then
                            Ok tv

                        else
                            Err "Minimum amount is 0.000000000000000001 DAI"
                    )
            )
