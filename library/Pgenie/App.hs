module Pgenie.App (main) where

import qualified Coalmine.EvenSimplerPaths as Path
import Coalmine.Prelude
import qualified Data.Text.IO as TextIO
import qualified Optima
import qualified Pgenie.Client as Client
import qualified Pgenie.Config.Model as Config
import qualified Pgenie.Config.Parsing as Parsing
import qualified System.Directory as Directory

main :: IO ()
main = do
  host <- readArgs
  config <- Parsing.fileInDir mempty
  migrations <- loadSqlFiles (#migrationsDir config)
  queries <- loadSqlFiles (#queriesDir config)
  generate True host Nothing config migrations queries

readArgs :: IO Text
readArgs =
  Optima.params "pgenie.io CLI app" $
    ( Optima.param Nothing "server" $
        Optima.value
          "Service server"
          (Optima.explicitlyRepresented id "pgenie.io")
          Optima.unformatted
          Optima.implicitlyParsed
    )

loadSqlFiles :: Path -> IO [(Path, Text)]
loadSqlFiles dir =
  Path.listDirectory dir >>= traverse load . sort . filter pred
  where
    pred path =
      case Path.extensions path of
        ["sql"] -> True
        ["psql"] -> True
        _ -> False
    load path =
      TextIO.readFile (printCompactAs path)
        <&> (path,)

generate ::
  Bool ->
  Text ->
  Maybe Int ->
  Config.Project ->
  [(Path, Text)] ->
  [(Path, Text)] ->
  IO ()
generate secure host port config migrations queries = do
  res <- Client.runHappily op secure host port
  results <- case res of
    Left err -> die (to err)
    Right res -> return res
  forM_ results $ \(nestPath -> path, contents) -> do
    Path.createDirsTo path
    liftIO $ TextIO.writeFile (printCompactAs path) contents
  where
    op =
      Client.process (#org config) (#name config) migrations queries
    nestPath path =
      #outputDir config <> path