import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as Events
import Url exposing (Url)


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = document
        , onUrlChange = GotUrlChange
        , onUrlRequest = GotUrlRequest
        }


type Msg
    = GotUrlChange Url
    | GotUrlRequest Browser.UrlRequest


type alias Model =
    { url : Url
    , key : Nav.Key
    }


type alias Flags =
    {}


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        model =
            { url = url
            , key = key
            }
    in
    ( model
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotUrlChange url ->
            ( { model | url = url }
            , Cmd.none
            )

        GotUrlRequest urlRequest ->
            ( model
            , case urlRequest of
                Browser.Internal internal ->
                    Url.toString internal
                        |> Nav.pushUrl model.key

                Browser.External url ->
                    Nav.load url
            )


document : Model -> Browser.Document Msg
document model =
    { title = "Application"
    , body = [ view model ]
    }


view : Model -> Html Msg
view model =
    Html.div
        []
        [ Html.text "hello"
        ]
