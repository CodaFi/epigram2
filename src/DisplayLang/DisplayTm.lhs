\section{DisplayTm}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE TypeOperators, GADTs, KindSignatures, RankNTypes,
>     TypeSynonymInstances, FlexibleInstances, FlexibleContexts,
>     ScopedTypeVariables,
>     DeriveFunctor, DeriveFoldable, DeriveTraversable #-}

> module DisplayLang.DisplayTm where

> import Control.Applicative
> import Data.Foldable hiding (foldl)
> import Data.Traversable

> import Kit.MissingLibrary

> import Features.Features

> import Evidences.Tm

%endif

%format ::$ = ":\!\!:\!\!\$"
%format ::. = ":\!\bullet"

\subsection{The Life Cycle of a Term}

The life cycle of a term in the system looks like this, where vertices are
labelled with the type of a representation, and edges are labelled with the
transformation between representations.

\begin{verbatim}
            Lexer             Parser            Elaborator
   String ---------> [Token] ---------> InDTmRN ----------> INTM
     ^                                                       |
     |                                                       |
     |  Renderer         Pretty-printer           Distiller  |
     +-------------- Doc <------------- InDTmRN <------------+
\end{verbatim}

In the beginning was the |String|. This gets lexed (section \ref{sec:lexer})
to produce a list of |Token|s, which are parsed (section \ref{sec:parser}) to
give an |InDTm RelName| (a term in the display syntax containing relative
names). The display term is then elaborated (section \ref{sec:elaborator})
in the |ProofState| monad to produce an |INTM| (a term in the evidence
language).

Reversing the process, the distiller (section \ref{sec:distiller}) converts
an evidence term back to a display term, and the pretty-printer
(section \ref{sec:pretty_printer}) renders this as a |String|.


\subsection{Structure of Display Terms}

Display terms correspond roughly to |Tm {d, TT}| in the evidence language, but
instead of taking a |Dir| parameter, we define two mutually recursive data
types. This allows us to use |deriving Traversable|. Again, they are polymorphic
in the representation of free variables. In addition to the structures from
the evidence language, we have the following:
\begin{itemize}
\item Question marks (holes) which are replaced by subgoals on elaboration.
\item Underscores which are determined by the typing rules on elaboration.
\item Embedding of evidence terms into display terms.
\item Type casts.
\item Extensions imported from an aspect.
\end{itemize}

However, we have removed the following:
\begin{itemize}
\item Type ascriptions (use type casts instead).
\item Operators (use parameters with appropriate references instead).
\end{itemize}

> data InDTm :: * -> * where
>     DL     :: DScope x                   -> InDTm  x -- \(\lambda\)
>     DC     :: Can (InDTm x)              -> InDTm  x -- canonical
>     DN     :: ExDTm x                    -> InDTm  x -- neutral
>     DQ     :: String                     -> InDTm  x -- hole
>     DU     ::                               InDTm  x -- underscore
>     DT     :: InTmWrap x                 -> InDTm  x -- embedding
>     import <- InDTmConstructors
>  deriving (Functor, Foldable, Traversable, Show)

> data ExDTm x = DHead x ::$ DSpine x
>   deriving (Functor, Foldable, Traversable, Show)

> data DHead :: * -> * where
>     DP     :: x                          -> DHead  x -- parameter
>     DType  :: InDTm x                    -> DHead  x -- type cast
>     DTEx   :: ExTmWrap x                 -> DHead  x -- embedding
>  deriving (Functor, Foldable, Traversable, Show)


\subsubsection{Scopes, canonical objects and eliminators}

Note that we reuse the |Can| and |Elim| functors from |Tm|.

The |DScope| functor is a simpler version of the |Scope| functor because it
doesn't need to deal with the |VV| phase.

> data DScope :: * -> * where
>     (::.)  :: String -> InDTm x          -> DScope x  -- binding
>     DK     :: InDTm x                    -> DScope x  -- constant
>   deriving (Functor, Foldable, Traversable, Show)

We provide handy projection functions to get the name and body of a scope:

> dScopeName :: DScope x -> String
> dScopeName (x ::. _)  = x
> dScopeName (DK _)     = "_"

> dScopeTm :: DScope x -> InDTm x
> dScopeTm (_ ::. tm)  = tm
> dScopeTm (DK tm)     = tm

Spines of eliminators are just like in the evidence language:

> type DSpine x = [Elim (InDTm x)]

> ($::$) :: ExDTm x -> Elim (InDTm x) -> ExDTm x
> (h ::$ s) $::$ a = h ::$ (s ++ [a])


\subsubsection{Embedding evidence terms}

The |DT| and |DTEx| constructors allow evidence terms to be treated as |In| and
|Ex| display terms, respectively. This is useful for elaboration, but such terms
cannot be pretty-printed. To make |deriving Traversable| work properly, we have
to |newtype|-wrap them and give trivial |Traversable| instances for the wrappers
manually.

> newtype InTmWrap  x = InTmWrap  INTM  deriving Show
> newtype ExTmWrap  x = ExTmWrap  EXTM  deriving Show

> pattern DTIN x = DT (InTmWrap x)
> pattern DTEX x = DTEx (ExTmWrap x)

%if False

> instance Functor InTmWrap where
>   fmap = fmapDefault
> instance Foldable InTmWrap where
>   foldMap = foldMapDefault
> instance Traversable InTmWrap where
>   traverse f (InTmWrap x) = pure (InTmWrap x)

> instance Functor ExTmWrap where
>   fmap = fmapDefault
> instance Foldable ExTmWrap where
>   foldMap = foldMapDefault
> instance Traversable ExTmWrap where
>   traverse f (ExTmWrap x) = pure (ExTmWrap x)

%endif


\subsubsection{Type casts}

Because type ascriptions are horrible things to parse, in the display language
we use type casts instead. The type cast |DType ty| gets elaborated to the
identity function for type |ty|, thereby pushing the type into its argument.
The distiller removes type ascriptions and replaces them with appropriate
type casts if necessary.


\subsection{Useful Abbreviations}

The convention for display term pattern synonyms is that they should match
their evidence term counterparts, but with the addition of |D|s in appropriate
places.

> pattern DSET        = DC Set              
> pattern DARR s t    = DPI s (DL (DK t)) 
> pattern DPI s t     = DC (Pi s t)         
> pattern DCON t      = DC (Con t)
> pattern DNP n       = DN (DP n ::$ [])
> pattern DLAV x t    = DL (x ::. t)
> pattern DPIV x s t  = DPI s (DLAV x t)
> pattern DLK t       = DL (DK t)
> pattern DTY ty tm   = DType ty ::$ [A tm]
> import <- CanDisplayPats

We need fewer type synoyms:

> type INDTM  = InDTm REF 
> type EXDTM  = ExDTm REF


\subsection{Term Construction} 

> dfortran :: InDTm x -> String
> dfortran (DL (x ::. _)) | not (null x) = x
> dfortran _ = "x"


\subsection{Schemes}

A definition may have a |Scheme|, which allows us to handle implicit syntax.
A |Scheme| is either a type, an explicit $\Pi$ whose domain and codomain are
schemes, or an implicit $\Pi$ whose domain is a type and whose codomain is
a scheme. A |Scheme| is a functor, parameterised by the representation of
types it uses.

> data Scheme x  =  SchType x
>                |  SchExplicitPi (String :<: Scheme x) (Scheme x)
>                |  SchImplicitPi (String :<: x) (Scheme x)
>   deriving Show

%if False

> instance Functor Scheme where
>     fmap = fmapDefault

> instance Foldable Scheme where
>     foldMap = foldMapDefault

> instance Traversable Scheme where
>     traverse f (SchType t) = (|SchType (f t)|)
>     traverse f (SchExplicitPi (x :<: schS) schT) =
>         (| SchExplicitPi (| (x :<:) (traverse f schS) |) (traverse f schT) |)
>     traverse f (SchImplicitPi (x :<: s) schT) = 
>         (| SchImplicitPi (| (x :<:) (f s) |) (traverse f schT) |)

%endif

Given a scheme, we can extract the names of its $\Pi$s:

> schemeNames :: Scheme x -> [String]
> schemeNames (SchType _) = []
> schemeNames (SchExplicitPi (x :<: _) sch) = x : schemeNames sch
> schemeNames (SchImplicitPi (x :<: _) sch) = x : schemeNames sch

We can also convert a |Scheme x| to an |x|, if we are given a way to
interpret $\Pi$-bindings:

> schemeToType :: (String -> x -> x -> x) -> Scheme x -> x
> schemeToType _ (SchType ty) = ty
> schemeToType piv (SchExplicitPi (x :<: s) t) = 
>     piv x (schemeToType piv s) (schemeToType piv t)
> schemeToType piv (SchImplicitPi (x :<: s) t) =
>     piv x s (schemeToType piv t)

> schemeToInTm :: Scheme (InTm x) -> InTm x
> schemeToInTm = schemeToType PIV

> schemeToInDTm :: Scheme (InDTm x) -> InDTm x
> schemeToInDTm = schemeToType DPIV


\subsection{Sizes}

We keep track of the |Size| of terms when parsing, to avoid nasty left
recursion, and when pretty-printing, to minimise the number of brackets we
output. In increasing order, the sizes are:

> data Size = ArgSize | AppSize | EqSize | AndSize | ArrSize | PiSize
>   deriving (Show, Eq, Enum, Bounded, Ord)

When a higher-size term has to be put in a lower-size position, it must
be wrapped in parentheses. For example, an application has |AppSize| but its
arguments have |ArgSize|, so |g (f x)| cannot be written |g f x|, whereas
|EqSize| is bigger than |AppSize| so |f x == g x| means the same thing as
|(f x) == (g x)|.


\subsection{Names}

For display and storage purposes, we have a system of local longnames for referring to entries.
Any component of a local name may have a \textasciicircum|n| or |_n| suffix, where |n| is
an integer, representing a relative or absolute offset. A relative
offset \textasciicircum|n| refers to the $n^\mathrm{th}$ occurrence of the name
encountered when searching upwards, so |x|\textasciicircum|0| refers to the same reference
as |x|, but |x|\textasciicircum|1| skips past it and refers to the next thing named |x|.
An absolute offset |_n|, by contrast, refers to the exact numerical
component of the name. 

> data Offs = Rel Int | Abs Int deriving Show
> type RelName = [(String,Offs)]

> type InTmRN = InTm RelName
> type ExTmRN = ExTm RelName
> type InDTmRN = InDTm RelName
> type ExDTmRN = ExDTm RelName


\subsection{Moving |StackError| from |INTM| to |InDTmRN|}

Some functions, such as |distill|, are defined in the |ProofStateT
INTM| monad. However, Cochon lives in a |ProofStateT InDTmRN|
monad. Therefore, in order to use it, we will need to lift from the
former to the latter.

> liftError :: Either (StackError INTM) a -> Either (StackError InDTmRN) a
> liftError = either (Left . wrapError) Right
>     where wrapError :: StackError INTM -> StackError InDTmRN
>           wrapError = fmap $           -- on the stack
>                       fmap $           -- on the list of token
>                       fmap             -- on a token
>                       (DT . InTmWrap)  -- turning INTM into InDTmRN
