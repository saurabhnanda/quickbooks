{-# LANGUAGE ImplicitParams    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies      #-}

------------------------------------------------------------------------------
-- |
-- Module      : QuickBooks
-- Description :
-- Copyright   :
-- License     :
-- Maintainer  :
-- Stability   :
-- Portability :
--
--
--
------------------------------------------------------------------------------

module QuickBooks
  ( createInvoice
  , readInvoice
  , updateInvoice
  , deleteInvoice
  , getTempTokens
  ) where

import QuickBooks.Authentication
import QuickBooks.Types        ( APIConfig(..)
                               , CallbackURL
                               , Invoice
                               , InvoiceId
                               , QuickBooksRequest(..)
                               , QuickBooksResponse(..)
                               , SyncToken
                               , OAuthToken
                               , QuickBooksQuery
                               , DeletedInvoice)
import QuickBooks.Invoice      ( createInvoiceRequest
                               , deleteInvoiceRequest
                               , readInvoiceRequest
                               , updateInvoiceRequest)

import Control.Applicative     ((<$>),(<*>))
import Control.Arrow           (second)
import Data.ByteString.Char8   (pack)
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Client     (newManager)
import System.Environment      (getEnvironment)
import System.Log.FastLogger
import Data.IORef
import System.IO.Unsafe

apiLogger :: IORef LoggerSet
apiLogger = unsafePerformIO $ do
  newIORef =<< newStdoutLoggerSet 0
   
-- | Create an invoice.
createInvoice :: Invoice -> IO (Either String (QuickBooksResponse Invoice))
createInvoice = queryQuickBooks . CreateInvoice

-- | Read an invoice.
readInvoice :: InvoiceId -> IO (Either String (QuickBooksResponse Invoice))
readInvoice = queryQuickBooks . ReadInvoice

-- | Update an invoice.
updateInvoice :: Invoice -> IO (Either String (QuickBooksResponse Invoice))
updateInvoice = queryQuickBooks . UpdateInvoice

-- | Delete an invoice.
deleteInvoice :: InvoiceId -> SyncToken -> IO (Either String (QuickBooksResponse DeletedInvoice))
deleteInvoice iId = queryQuickBooks . DeleteInvoice iId

getTempTokens :: CallbackURL -> IO (Either String (QuickBooksResponse OAuthToken))
getTempTokens = queryQuickBooks . GetTempOAuthCredentials

queryQuickBooks :: QuickBooksQuery a -> IO (Either String (QuickBooksResponse a))
queryQuickBooks query = do
  apiConfig <- readAPIConfig
  manager   <- newManager tlsManagerSettings
  logger    <- readIORef apiLogger
  let ?apiConfig = apiConfig
  let ?manager   = manager
  let ?logger    = logger
  case query of
    (CreateInvoice invoice)               -> createInvoiceRequest invoice
    (UpdateInvoice invoice)               -> updateInvoiceRequest invoice
    (ReadInvoice invoiceId)               -> readInvoiceRequest invoiceId
    (DeleteInvoice invoiceId syncToken)   -> deleteInvoiceRequest invoiceId syncToken
    (GetTempOAuthCredentials callbackURL) -> getTempOAuthCredentialsRequest callbackURL

readAPIConfig :: IO APIConfig
readAPIConfig = do
  env <- getEnvironment
  case lookupAPIConfig env of
    Just config -> return config
    Nothing     -> fail "INTUIT_COMPANY_ID,INTUIT_CONSUMER_KEY,INTUIT_CONSUMER_SECRET,INTUIT_TOKEN,INTUIT_SECRET,INTUIT_HOSTNAME must be set"

lookupAPIConfig :: [(String, String)] -> Maybe APIConfig
lookupAPIConfig environment = APIConfig <$> lookup "INTUIT_COMPANY_ID" env
                                        <*> lookup "INTUIT_CONSUMER_KEY" env
                                        <*> lookup "INTUIT_CONSUMER_SECRET" env
                                        <*> lookup "INTUIT_TOKEN" env
                                        <*> lookup "INTUIT_SECRET" env
                                        <*> lookup "INTUIT_HOSTNAME" env
    where env = map (second pack) environment
