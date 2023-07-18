port module Main exposing (Model, Msg(..), formUX, init, main, update, view)

import Asset
import Browser
import Html.Styled exposing (Attribute, Html, a, button, div, h1, img, input, text, toUnstyled)
import Html.Styled.Attributes exposing (css, disabled, href, placeholder, src, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Tailwind.Utilities as TW


port accountRequested : String -> Cmd msg


port accountSucceeded : (Wallet -> msg) -> Sub msg


port accountFailed : (String -> msg) -> Sub msg


port approveRequested : Int -> Cmd msg


port approveSucceeded : (String -> msg) -> Sub msg


port approveFailed : (String -> msg) -> Sub msg


port mintRequested : Int -> Cmd msg


port mintSucceeded : (String -> msg) -> Sub msg


port mintFailed : (String -> msg) -> Sub msg



---- MODEL ----


type UX
    = AccountNotFound
    | ConnectAccount (Maybe String)
    | FormUX (Maybe String)
    | LoadingUX String
    | SubmittedUX


type alias Wallet =
    { address : String
    , stablecoinBalance : String
    , stablecoinSymbol : String
    , network : String
    , stablecoinFee : String
    , algobullBalance : String
    }


type alias Model =
    { quantity : Int
    , ux : UX
    , wallet : Maybe Wallet
    , scanUrl : String
    }


init : Bool -> ( Model, Cmd Msg )
init walletFound =
    case walletFound of
        False ->
            ( { quantity = 0, ux = AccountNotFound, wallet = Nothing, scanUrl = "" }, Cmd.none )

        True ->
            ( { quantity = 0, ux = ConnectAccount Nothing, wallet = Nothing, scanUrl = "" }, Cmd.none )



---- UPDATE ----


type Msg
    = AccountRequested
    | AccountFailed String
    | AccountSucceeded Wallet
    | ApproveRequested
    | ApproveFailed String
    | ApproveSucceeded String
    | MintRequested String
    | MintSucceeded String
    | MintFailed String
    | QuantityUpdated String


stringFloatInt : String -> Int
stringFloatInt =
    String.toFloat
        >> Maybe.map round
        >> Maybe.withDefault 0


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AccountRequested ->
            ( { model | ux = LoadingUX "Connecting wallet" }, accountRequested "" )

        AccountFailed err ->
            ( { model | ux = ConnectAccount (Just err) }, Cmd.none )

        AccountSucceeded wallet ->
            ( { model | ux = FormUX Nothing, wallet = Just wallet }, Cmd.none )

        QuantityUpdated quantityStr ->
            let
                quantity =
                    quantityStr
                        |> String.toInt
                        |> Maybe.withDefault 0
            in
            ( { model
                | quantity = quantity
                , ux = FormUX Nothing
              }
            , Cmd.none
            )

        ApproveRequested ->
            model.wallet
                |> Maybe.map
                    (\wallet ->
                        let
                            totalFee =
                                model.quantity * stringFloatInt wallet.stablecoinFee
                        in
                        ( { model
                            | ux =
                                LoadingUX <|
                                    "Submitting approval to transfer "
                                        ++ String.fromInt totalFee
                                        ++ " "
                                        ++ wallet.stablecoinSymbol
                                        ++ "..."
                          }
                        , approveRequested totalFee
                        )
                    )
                |> Maybe.withDefault ( model, Cmd.none )

        ApproveFailed err ->
            ( { model | ux = FormUX (Just err) }, Cmd.none )

        ApproveSucceeded _ ->
            ( { model | ux = LoadingUX <| "Submitting minting request of " ++ String.fromInt model.quantity ++ " ALGOBULL..." }, mintRequested model.quantity )

        MintRequested _ ->
            ( { model | ux = LoadingUX "Submitting mint transaction" }, mintRequested model.quantity )

        MintSucceeded scanUrl ->
            ( { model | ux = SubmittedUX, scanUrl = scanUrl }, Cmd.none )

        MintFailed err ->
            ( { model | ux = FormUX (Just err) }, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Mint some ALGOBULL!" ]
        , case model.ux of
            AccountNotFound ->
                div []
                    [ div []
                        [ text "Looks like you'll need a wallet to mint ALGOBULL. "
                        , text " Download "
                        , a [ href "https://metamask.io/download/" ] [ text "MetaMask." ]
                        ]
                    ]

            ConnectAccount err ->
                connectAccountUX model err

            FormUX err ->
                formUX err model

            LoadingUX str ->
                loadingUX model str

            SubmittedUX ->
                submittedUX model
        ]


connectAccountUX : Model -> Maybe String -> Html Msg
connectAccountUX model err =
    let
        errorContent =
            case err of
                Just str ->
                    errorText str

                Nothing ->
                    div [] []
    in
    div []
        [ errorContent
        , div []
            [ brandedButton
                [ onClick AccountRequested
                , css
                    [ TW.px_4
                    , TW.py_2
                    ]
                ]
                [ img [ src (Asset.toPath Asset.metamaskLogo), css [ TW.text_base, TW.mr_3 ] ] [] ]
                "Connect Wallet"
            ]
        ]


brandedButton : List (Attribute Msg) -> List (Html Msg) -> String -> Html Msg
brandedButton attrs nodes str =
    let
        btnAttrs =
            [ css
                [ TW.inline_flex
                , TW.align_middle
                , TW.items_center
                , TW.justify_center
                , TW.cursor_pointer
                , TW.w_full
                , TW.h_12
                , TW.text_lg
                ]
            ]
                ++ attrs

        btnNodes =
            nodes ++ [ text str ]
    in
    button btnAttrs btnNodes


loadingUX : Model -> String -> Html Msg
loadingUX model str =
    div [] [ text str ]


submittedUX : Model -> Html Msg
submittedUX model =
    div []
        [ div [] [ text <| "Congrats! You successfully minted " ++ String.fromInt model.quantity ++ " ALGOBULL!" ]
        , div [] [ a [ href model.scanUrl ] [ text "🔗 Transaction URL" ] ]
        ]


errorText : String -> Html Msg
errorText str =
    div [ css [ TW.my_4 ] ] [ text str ]


formUX : Maybe String -> Model -> Html Msg
formUX maybeFailure model =
    div []
        [ div []
            [ model.wallet |> Maybe.map walletView |> Maybe.withDefault (div [] [])
            , div [ css [ TW.my_2 ] ]
                [ input
                    [ onInput QuantityUpdated
                    , css [ TW.box_border, TW.w_full, TW.px_5, TW.text_lg, TW.h_12 ]
                    , type_ "number"
                    , placeholder "Enter Amount"
                    , value <| String.fromInt model.quantity
                    ]
                    []
                ]
            , div []
                [ brandedButton
                    [ onClick ApproveRequested
                    , css [ TW.w_full ]
                    , disabled <| not <| validateForm model
                    ]
                    []
                    (balanceWarningOrMint model)
                ]
            ]
        , model.wallet |> Maybe.map (feeView model.quantity) |> Maybe.withDefault (div [] [])
        ]


balanceWarningOrMint : Model -> String
balanceWarningOrMint model =
    case model.wallet of
        Just wallet ->
            if hasFunds model.quantity wallet then
                "Mint"

            else
                "Not enough " ++ " " ++ wallet.stablecoinSymbol

        Nothing ->
            "Wallet not found"


hasFunds : Int -> Wallet -> Bool
hasFunds quantity wallet =
    let
        fee =
            stringFloatInt wallet.stablecoinFee * quantity

        balance =
            stringFloatInt wallet.stablecoinBalance
    in
    balance >= fee


validateForm : Model -> Bool
validateForm model =
    case ( model.quantity, model.wallet ) of
        ( 0, _ ) ->
            False

        ( _, Just wallet ) ->
            hasFunds model.quantity wallet

        ( _, _ ) ->
            False


walletView : Wallet -> Html Msg
walletView wallet =
    div []
        [ div [ css [ TW.text_sm ] ] [ text <| "NFT balance: " ++ wallet.algobullBalance ++ " ALGOBULL" ]
        , div [ css [ TW.text_sm ] ] [ text <| "Stablecoin balance: " ++ wallet.stablecoinBalance ++ " " ++ wallet.stablecoinSymbol ]
        ]


feeView : Int -> Wallet -> Html Msg
feeView quantity wallet =
    let
        fee =
            String.fromInt (stringFloatInt wallet.stablecoinFee * quantity)
    in
    case fee of
        "0" ->
            div [] []

        _ ->
            div []
                [ div [ css [ TW.text_sm, TW.my_2 ] ] [ text <| "Fee: " ++ fee ++ " " ++ wallet.stablecoinSymbol ]
                ]



---- PROGRAM ----


main : Program Bool Model Msg
main =
    Browser.element
        { view = view >> toUnstyled
        , init = init
        , update = update
        , subscriptions =
            \model ->
                Sub.batch
                    [ accountSucceeded AccountSucceeded
                    , accountFailed AccountFailed
                    , mintSucceeded MintSucceeded
                    , mintFailed MintFailed
                    , approveSucceeded ApproveSucceeded
                    , approveFailed ApproveFailed
                    ]
        }
