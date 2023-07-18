module Asset exposing (Asset, metamaskLogo, toPath)


toPath : Asset -> String
toPath (Asset filename) =
    "/images/" ++ filename


type Asset
    = Asset String


metamaskLogo : Asset
metamaskLogo =
    Asset "metamask-logo.svg"
