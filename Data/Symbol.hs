-- Copyright (c) 2009-2010
--         The President and Fellows of Harvard College.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
-- 3. Neither the name of the University nor the names of its contributors
--    may be used to endorse or promote products derived from this software
--    without specific prior written permission.

-- THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE UNIVERSITY OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.

--------------------------------------------------------------------------------
-- |
-- Module      :  Data.Symbol
-- Copyright   :  (c) Harvard University 2009-2010
-- License     :  BSD-style
-- Maintainer  :  mainland@eecs.harvard.edu
--
--------------------------------------------------------------------------------

{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveDataTypeable #-}

module Data.Symbol (
    Symbol,
    intern,
    intern',
    unintern,
    unintern'
  ) where

import Control.Concurrent.MVar
import Control.DeepSeq ( NFData, rnf )
#if __GLASGOW_HASKELL__ >= 608
import Data.String
#endif /* __GLASGOW_HASKELL__ >= 608 */
import qualified Data.Bimap as BM
import System.IO.Unsafe (unsafePerformIO)

newtype Symbol = Symbol Int

instance Eq Symbol where
    (Symbol i1) == (Symbol i2) = i1 == i2

instance Ord Symbol where
    compare (Symbol i1) (Symbol i2) = compare i1 i2

instance NFData Symbol where
  rnf (Symbol a) = rnf a

data SymbolEnv = SymbolEnv
    { uniq    :: {-# UNPACK #-} !Int
    , symbols :: !(BM.Bimap String Int)
    }

symbolEnv :: MVar SymbolEnv
symbolEnv = unsafePerformIO $ newMVar $ SymbolEnv 1 BM.empty

-- We @seq@ @s@ so that we can guarantee that when we perform the lookup we
-- won't potentially have to evaluate a thunk that might itself call @intern@,
-- leading to a deadlock.

-- |Intern a string to produce a 'Symbol'.
{-# NOINLINE intern #-}
intern :: String -> Symbol
intern s = s `seq` unsafePerformIO $ modifyMVar symbolEnv $ \env -> do
    case BM.lookup s (symbols env) of
      Nothing  -> do let sym  = uniq env
                     let env' = env { uniq    = uniq env + 1,
                                      symbols = BM.insert s sym
                                                (symbols env)
                                    }
                     env' `seq` return (env', Symbol sym)
      Just sym -> return (env, Symbol sym)

intern' :: String -> Int
intern' s = let Symbol i = intern s in i

-- |Return the 'String' associated with a 'Symbol'.
{-# NOINLINE unintern #-}
unintern' :: Int -> String
unintern' i = unsafePerformIO $ withMVar symbolEnv $ \env -> let str = (symbols env) BM.!> i
                                                             in str `seq` return str

unintern :: Symbol -> String
unintern (Symbol i) = unintern' i
