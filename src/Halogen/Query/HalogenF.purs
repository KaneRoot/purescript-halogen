module Halogen.Query.HalogenF
  ( HalogenF(..)
  , RenderPending(..)
  , transformHF
  , hoistHalogenF
  ) where

import Prelude

import Control.Alt (class Alt)
import Control.Monad.Aff.Free (class Affable, fromAff)
import Control.Monad.Free.Trans (hoistFreeT, bimapFreeT)
import Control.Plus (class Plus)

import Data.Bifunctor (lmap)
import Data.Maybe (Maybe)

import Halogen.Query.EventSource (EventSource(..), runEventSource)
import Halogen.Query.StateF (StateF)

data RenderPending = Pending | Deferred

-- | The Halogen component algebra
data HalogenF s f g a
  = StateHF (StateF s a)
  | SubscribeHF (EventSource f g) a
  | QueryFHF (f a)
  | QueryGHF (g a)
  | RenderHF (Maybe RenderPending) a
  | RenderPendingHF (Maybe RenderPending -> a)
  | HaltHF

instance functorHalogenF :: (Functor f, Functor g) => Functor (HalogenF s f g) where
  map f = case _ of
    StateHF q -> StateHF (map f q)
    SubscribeHF es a -> SubscribeHF es (f a)
    QueryFHF q -> QueryFHF (map f q)
    QueryGHF q -> QueryGHF (map f q)
    RenderHF r a -> RenderHF r (f a)
    RenderPendingHF k -> RenderPendingHF (f <$> k)
    HaltHF -> HaltHF

instance affableHalogenF :: Affable eff g => Affable eff (HalogenF s f g) where
  fromAff = QueryGHF <<< fromAff

instance altHalogenF :: (Functor f, Functor g) => Alt (HalogenF s f g) where
  alt HaltHF h = h
  alt h _ = h

instance plusHalogenF :: (Functor f, Functor g) => Plus (HalogenF s f g) where
  empty = HaltHF

-- | Change all the parameters of `HalogenF`.
transformHF
  :: forall s s' f f' g g'
   . Functor g'
  => (StateF s ~> StateF s')
  -> f ~> f'
  -> g ~> g'
  -> HalogenF s f g
  ~> HalogenF s' f' g'
transformHF natS natF natG h =
  case h of
    StateHF q -> StateHF (natS q)
    SubscribeHF es next -> SubscribeHF (EventSource (bimapFreeT (lmap natF) natG (runEventSource es))) next
    QueryFHF q -> QueryFHF (natF q)
    QueryGHF q -> QueryGHF (natG q)
    RenderHF r a -> RenderHF r a
    RenderPendingHF k -> RenderPendingHF k
    HaltHF -> HaltHF

-- | Changes the `g` for a `HalogenF`. Used internally by Halogen.
hoistHalogenF
  :: forall s f g h
   . Functor h
  => g ~> h
  -> HalogenF s f g
  ~> HalogenF s f h
hoistHalogenF eta h =
  case h of
    StateHF q -> StateHF q
    SubscribeHF es next -> SubscribeHF (EventSource (hoistFreeT eta (runEventSource es))) next
    QueryFHF q -> QueryFHF q
    QueryGHF q -> QueryGHF (eta q)
    RenderHF r a -> RenderHF r a
    RenderPendingHF k -> RenderPendingHF k
    HaltHF -> HaltHF
