{-# LANGUAGE FunctionalDependencies     #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE RankNTypes                 #-}
{-# LANGUAGE TypeSynonymInstances       #-}

{-# LANGUAGE AllowAmbiguousTypes        #-}
{-# LANGUAGE FlexibleInstances          #-}

{-# LANGUAGE KindSignatures             #-}
{-# LANGUAGE UndecidableInstances #-}
module Types.FD where

import           Control.Monad.Reader
import           Control.Monad.State
import           Control.Monad.Trans

class Coll c e | c -> e where
  empty :: c
  insert :: c -> e -> c
  member :: c -> e -> Bool


-- [a] determines e should be a.
instance Eq a => Coll [a] a where
  empty = []
  insert xs a = a : xs
  member xs e = e `elem` xs

-- type checker infer to c -> e -> e -> c instead of c -> e1 -> e2 -> c
ins2 xs a b = insert (insert xs a) b

-- without functional dependencies even with same c in the context we can't say
-- what type e will be, so you can only assume different instances of e are different types.
class Coll' c e where
  empty' :: c
  insert' :: c -> e -> c
  member' :: c -> e -> Bool


{-@ Undecidable instance ?

    - It's commonly needed for multiparamter typeclass when recurse on the non functional
    dependend part.

    - Haskell wants all instance to be decidable by default, but in lots' of cases it's just
    not possible.

@-}

-- Bad example:

-- class MonadIO' (m :: * -> *) where
--   liftIO' :: IO a -> m a

-- this is an example of a generic instance for all MonadIO of type (t :: (* -> *) -> * -> *)
-- and m :: * -> *.
-- It works for all instances with (t m) being a monad, t being a monad trans and m being a
-- MonadIO.


-- PROBLEM of this instance --
--    1. overlapping
--        It's too generic and exlucde people implementing instance with the same shape.
--    2. undecidable instance
--        It's undecidable because constraint (Monad (t m)) has the same type parameter
--        as (MonadIO (t m)), no constructor is removed. Haskell requires constraint
--        of instance at least remove one type constructor to make sure it's smaller
--        than the instance head.
instance (Monad m, Monad (t m), MonadIO m, MonadTrans t) => MonadIO (t m) where
  liftIO = lift . liftIO

data SomeEnv = SomeEnv
  { v1 :: Int
  , v2 :: String
  , v3 :: forall a. [(String, a)]
  }

data Rec = Rec
  { intList    :: [(String, Int)]
  , stringList :: [(String, String)]
  }

-- now let's make an arbitray transformer stack.
newtype MTStack m a = MTStack { unMTStack :: ReaderT SomeEnv (StateT Rec m) a }
  deriving (Functor, Applicative, Monad, MonadReader SomeEnv, MonadState Rec)


instance MonadTrans MTStack where     -- still need to make MTStack a monad transformer.
  lift ma = MTStack $ do
    a <- lift . lift  $ ma
    return a

-- This will be an overlapping instance! Because the generic isntance defined above already
-- can be applied to MTStack m a.
-- instance MonadIO (MTStack IO) where
--   liftIO = lift . liftIO

foo :: MTStack IO ()
foo = do
   v <- v1 <$> ask
   liftIO $ putStrLn "asd"
   return ()


{-@ Why UndecidableInstances is usually needed for MPTC and FD?
@-}

-- first let's try to define a mtl style MonadState.
-- It's a MPTC with function dependency, it says given monad m, the state of
-- MonadState is uniquely defined to be s.
class Monad m => MonadState' s m | m -> s where
  get' :: m s
  get' = state' (\s -> (s, s))

  put' :: s -> m ()
  put' s = state' (\_ -> ((), s))

  state' :: (s -> (a, s)) -> m a
  state' f = do
    s <- get'
    let (a, s') = f s
    put' s
    return a

-- follow the curse of n^2 instances, let's implement MonadState for ReaderT monad
-- transformer.

-- According to haskell's standard, this is undecidable instance
-- A decidable instance needs to have a smaller constraint than then instace head.
-- All constraints should at least eliminate one type constructor, so by induction haskell
-- knows the instances for sure terminates.
--
-- Because MonadState is MPTC, our instance only eliminate constructor of (ReaderT e m)
-- but not on s, so it's undecidable.
--
-- But it's really decidable because s is determined by m, so if m is shrinking it doesn't
-- matter what s is since it's a function of m.
--
-- So in these case it's ok to use undecidable instances.
instance MonadState' s m => MonadState' s (ReaderT e m)





{-@ We can replace FD with type family. This way we don't need to show the
    function dependency in the instance context, thus no undecidable instances is
    needed.
@-}