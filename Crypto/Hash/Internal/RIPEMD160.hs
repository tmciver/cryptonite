-- |
-- Module      : Crypto.Hash.Internal.RIPEMD160
-- License     : BSD-style
-- Maintainer  : Vincent Hanquez <vincent@snarc.org>
-- Stability   : experimental
-- Portability : unknown
--
-- A module containing RIPEMD160 bindings
--
{-# LANGUAGE ForeignFunctionInterface #-}
module Crypto.Hash.Internal.RIPEMD160
    ( Ctx(..)
    -- * Internal values
    , digestSize
    , sizeCtx
    -- * Internal IO hash functions
    , internalInit
    , internalInitAt
    , internalUpdate
    , internalUpdateUnsafe
    , internalFinalize
    -- * Context copy and creation
    , withCtxCopy
    , withCtxNewThrow
    , withCtxThrow
    ) where

import           Foreign.Ptr
import           Crypto.Internal.ByteArray (ByteArrayAccess, ByteArray)
import qualified Crypto.Internal.ByteArray as B
import           Data.Word
import           Crypto.Internal.Memory

newtype Ctx = Ctx Bytes

{-# INLINE digestSize #-}
digestSize :: Int
digestSize = 20

{-# INLINE sizeCtx #-}
sizeCtx :: Int
sizeCtx = 128

withCtxCopy :: Ctx -> (Ptr Ctx -> IO ()) -> IO Ctx
withCtxCopy (Ctx b) f = Ctx `fmap` bytesCopyAndModify b f

withCtxThrow :: Ctx -> (Ptr Ctx -> IO a) -> IO a
withCtxThrow (Ctx b) f = bytesCopyTemporary b f

withCtxNewThrow :: (Ptr Ctx -> IO a) -> IO a
withCtxNewThrow f = bytesTemporary 128 f

foreign import ccall unsafe "cryptonite_ripemd.h cryptonite_ripemd160_init"
    c_ripemd160_init :: Ptr Ctx -> IO ()

foreign import ccall "cryptonite_ripemd.h cryptonite_ripemd160_update"
    c_ripemd160_update :: Ptr Ctx -> Ptr Word8 -> Word32 -> IO ()

foreign import ccall unsafe "cryptonite_ripemd.h cryptonite_ripemd160_update"
    c_ripemd160_update_unsafe :: Ptr Ctx -> Ptr Word8 -> Word32 -> IO ()

foreign import ccall unsafe "cryptonite_ripemd.h cryptonite_ripemd160_finalize"
    c_ripemd160_finalize :: Ptr Ctx -> Ptr Word8 -> IO ()

internalInitAt :: Ptr Ctx -> IO ()
internalInitAt = c_ripemd160_init

-- | init a context
internalInit :: IO Ctx
internalInit = Ctx `fmap` bytesAlloc 128 internalInitAt

-- | Update a context in place
internalUpdate :: ByteArrayAccess ba => Ptr Ctx -> ba -> IO ()
internalUpdate ptr d =
    B.withByteArray d $ \cs -> c_ripemd160_update ptr cs (fromIntegral $ B.length d)

-- | Update a context in place using an unsafe foreign function call.
--
-- It is faster than `internalUpdate`, but will block the haskell runtime.
-- This shouldn't be used if the input data is large.
internalUpdateUnsafe :: ByteArrayAccess ba => Ptr Ctx -> ba -> IO ()
internalUpdateUnsafe ptr d =
    B.withByteArray d $ \cs -> c_ripemd160_update_unsafe ptr cs (fromIntegral $ B.length d)

-- | Finalize a context in place
internalFinalize :: ByteArray output => Ptr Ctx -> IO output
internalFinalize ptr = B.alloc digestSize (c_ripemd160_finalize ptr)
