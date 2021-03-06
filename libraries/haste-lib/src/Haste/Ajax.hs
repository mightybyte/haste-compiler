{-# LANGUAGE CPP                      #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings        #-}
-- | Low level XMLHttpRequest support. IE6 and older are not supported.
module Haste.Ajax (Method (..), URL, Key, Val, textRequest, textRequest_,
                   jsonRequest, jsonRequest_) where

-------------------------------------------------------------------------------
import           Control.Monad.IO.Class
import           Haste
import           Haste.JSON
-------------------------------------------------------------------------------

#ifdef __HASTE__
foreign import ccall ajaxReq :: JSString    -- method
                             -> JSString    -- url
                             -> Bool        -- async?
                             -> JSString    -- POST data
                             -> JSFun (Maybe JSString -> IO ())
                             -> IO ()
#else
ajaxReq :: JSString -> JSString -> Bool -> JSString -> JSFun (Maybe JSString -> IO ()) -> IO ()
ajaxReq = error "Tried to use ajaxReq in native code!"
#endif

data Method = GET | POST deriving Show
type Key = String
type Val = String

-- | Make an AJAX request to a URL, treating the response as plain text.
textRequest :: MonadIO m
            => Method
            -> URL
            -> [(Key, Val)]
            -> (Maybe String -> IO ())
            -> m ()
textRequest m url kv cb = do
  _ <- liftIO $ ajaxReq (toJSString $ show m) url' True "" cb'
  return ()
  where
    cb' = mkCallback $ cb . fmap fromJSStr
    kv' = map (\(k,v) -> (toJSString k, toJSString v)) kv
    url' = if null kv
             then toJSString url
             else catJSStr "?" [toJSString url, toQueryString kv']

-- | Same as 'textRequest' but deals with JSStrings instead of Strings.
textRequest_ :: MonadIO m
             => Method
             -> JSString
             -> [(JSString, JSString)]
             -> (Maybe JSString -> IO ())
             -> m ()
textRequest_ m url kv cb = liftIO $ do
  _ <- ajaxReq (toJSString $ show m) url' True "" (mkCallback cb)
  return ()
  where
    url' = if null kv then url else catJSStr "?" [url, toQueryString kv]

-- | Make an AJAX request to a URL, interpreting the response as JSON.
jsonRequest :: MonadIO m
            => Method
            -> URL
            -> [(Key, Val)]
            -> (Maybe JSON -> IO ())
            -> m ()
jsonRequest m url kv cb = liftIO $ do
  jsonRequest_ m (toJSString url)
                 (map (\(k,v) -> (toJSString k, toJSString v)) kv)
                 cb

-- | Does the same thing as 'jsonRequest' but uses 'JSString's instead of
--   Strings.
jsonRequest_ :: MonadIO m
             => Method
             -> JSString
             -> [(JSString, JSString)]
             -> (Maybe JSON -> IO ())
             -> m ()
jsonRequest_ m url kv cb = liftIO $ do
  _ <- ajaxReq (toJSString $ show m) url' True pd cb'
  return ()
  where
    liftEither (Right x) = Just x
    liftEither _         = Nothing
    cb' = mkCallback $ \mjson -> cb (mjson >>= liftEither . decodeJSON)
    url' = case m of
             GET -> if null kv then url else catJSStr "?" [url, toQueryString kv]
             POST -> url
    pd = case m of
           GET -> ""
           POST -> if null kv then "" else toQueryString kv


toQueryString :: [(JSString, JSString)] -> JSString
toQueryString = catJSStr "&" . map (\(k,v) -> catJSStr "=" [k,v])
