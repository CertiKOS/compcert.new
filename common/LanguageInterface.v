Require Import String.
Require Import Coqlib.
Require Import AST.
Require Import Integers.
Require Import Floats.
Require Import Values.
Require Import Memory.
Require Import Globalenvs.

(** * Semantic interface of languages *)

Structure language_interface :=
  mk_language_interface {
    query: Type;
    reply: Type;
    dummy_query: query;
  }.

Arguments dummy_query {_}.

(** ** Interface for C-like languages *)

Record c_query :=
  cq {
    cq_id: string;
    cq_sg: signature;
    cq_args: list val;
    cq_mem: mem;
  }.

Canonical Structure li_c :=
  {|
    query := c_query;
    reply := val * mem;
    dummy_query := (cq EmptyString signature_main nil Mem.empty);
  |}.

(** ** Miscellaneous interfaces *)

Definition li_wp :=
  {|
    query := unit;
    reply := int;
    dummy_query := tt;
  |}.

Definition li_empty :=
  {|
    query := unit;
    reply := Empty_set;
    dummy_query := tt;
  |}.

(** XXX temporary fix: external functions are identified with a [string],
  but internal functions use [AST.ident]. To work around this
  discrepancy, we introduce the following mapping. *)
Parameter str2ident : string -> ident.

(** * Calling conventions *)

(** ** Definition *)

Record callconv T1 T2 :=
  mk_callconv {
    world_def: Type;
    dummy_world_def: world_def;
    match_senv:
      world_def -> Senv.t -> Senv.t -> Prop;
    match_query_def:
      world_def -> query T1 -> query T2 -> Prop;
    match_reply_def:
      world_def -> query T1 -> query T2 -> reply T1 -> reply T2 -> Prop;
    match_dummy_query_def:
      match_query_def dummy_world_def dummy_query dummy_query;
  }.

Record world {T1 T2} (cc: callconv T1 T2) :=
  mk_world {
    world_proj :> world_def T1 T2 cc;
    world_q1: query T1;
    world_q2: query T2;
    world_match_query:
      match_query_def T1 T2 cc world_proj world_q1 world_q2;
  }.

Arguments mk_world {T1 T2} cc _ _ _ _.
Arguments world_q1 {T1 T2 cc} _.
Arguments world_q2 {T1 T2 cc} _.

Program Definition dummy_world {T1 T2 cc}: world cc :=
  mk_world cc _ _ _ (match_dummy_query_def T1 T2 cc).

Inductive match_query {T1 T2} cc: world cc -> query T1 -> query T2 -> Prop :=
  match_query_intro w q1 q2 Hq:
    match_query cc (mk_world cc w q1 q2 Hq) q1 q2.

Inductive match_reply {T1 T2} cc: world cc -> reply T1 -> reply T2 -> Prop :=
  match_reply_intro w q1 q2 r1 r2 Hq:
    match_reply_def T1 T2 cc w q1 q2 r1 r2 ->
    match_reply cc (mk_world cc w q1 q2 Hq) r1 r2.

Lemma match_query_determ {T1 T2} (cc: callconv T1 T2) w q q1 q2:
  match_query cc w q q1 ->
  match_query cc w q q2 ->
  q2 = q1.
Proof.
  intros H1 H2.
  destruct H1; inv H2.
  reflexivity.
Qed.

(** ** Identity *)

Program Definition cc_id {T}: callconv T T :=
  {|
    world_def := unit;
    dummy_world_def := tt;
    match_senv w := eq;
    match_query_def w := eq;
    match_reply_def w q1 q2 := eq;
  |}.

Lemma match_cc_id {T} q:
  exists w,
    match_query (@cc_id T) w q q /\
    forall r1 r2,
      match_reply (@cc_id T) w r1 r2 ->
      r1 = r2.
Proof.
  exists (mk_world cc_id tt q q eq_refl).
  split.
  - constructor.
  - inversion 1.
    congruence.
Qed.

Lemma match_query_cc_id {T} w q1 q2:
  match_query (@cc_id T) w q1 q2 ->
  q1 = q2.
Proof.
  destruct 1.
  assumption.
Qed.

Lemma match_reply_cc_id {T} w r:
  match_reply (@cc_id T) w r r.
Proof.
  destruct w.
  repeat constructor.
Qed.

(** ** Composition *)

Section COMPOSE.
  Context {li1 li2 li3} (cc12: callconv li1 li2) (cc23: callconv li2 li3).

  Program Definition cc_compose :=
    {|
      world_def := world_def _ _ cc12 * world_def _ _ cc23 * query li2;
      dummy_world_def :=
        (dummy_world_def _ _ cc12, dummy_world_def _ _ cc23, dummy_query);
      match_senv w ge1 ge3 :=
        exists ge2,
          match_senv li1 li2 cc12 (fst (fst w)) ge1 ge2 /\
          match_senv li2 li3 cc23 (snd (fst w)) ge2 ge3;
      match_query_def w q1 q3 :=
        let '(w12, w23, q2) := w in
          match_query_def li1 li2 cc12 w12 q1 q2 /\
          match_query_def li2 li3 cc23 w23 q2 q3;
      match_reply_def w q1 q3 r1 r3 :=
        let '(w12, w23, q2) := w in
        exists r2,
          match_reply_def li1 li2 cc12 w12 q1 q2 r1 r2 /\
          match_reply_def li2 li3 cc23 w23 q2 q3 r2 r3;
    |}.
  Next Obligation.
    eauto using match_dummy_query_def.
  Qed.

  Definition comp_fst (w: world cc_compose) :=
    let '(mk_world (w12, w23, q2) q1 q3 (conj Hq12 Hq23)) := w in
    mk_world cc12 w12 q1 q2 Hq12.

  Definition comp_snd (w: world cc_compose) :=
    let '(mk_world (w12, w23, q2) q1 q3 (conj Hq12 Hq23)) := w in
    mk_world cc23 w23 q2 q3 Hq23.

  Lemma match_query_cc_compose (P: _ -> _ -> _ -> _ -> Prop):
    (forall w12 q1 q2, match_query cc12 w12 q1 q2 ->
     forall w23 q2' q3, match_query cc23 w23 q2' q3 ->
     q2' = q2 ->
     P w12 w23 q1 q3) ->
    (forall w q1 q3, match_query cc_compose w q1 q3 ->
     P (comp_fst w) (comp_snd w) q1 q3).
  Proof.
    intros H w q1 q3 Hq.
    destruct Hq as [w q1 q3 Hq].
    destruct w as [[w12 w23] q2].
    destruct Hq as [Hq12 Hq23].
    assert (match_query cc12 (mk_world _ w12 q1 q2 Hq12) q1 q2) by constructor.
    assert (match_query cc23 (mk_world _ w23 q2 q3 Hq23) q2 q3) by constructor.
    simpl in *.
    eauto.
  Qed.

  Lemma match_reply_cc_compose w r1 r2 r3:
    match_reply cc12 (comp_fst w) r1 r2 ->
    match_reply cc23 (comp_snd w) r2 r3 ->
    match_reply cc_compose w r1 r3.
  Proof.
    intros H12 H23.
    destruct w as [[[w12 w23] q2] q1 q3 [Hq12 Hq23]].
    simpl in *.
    inv H12.
    inv H23.
    constructor.
    exists r2.
    eauto.
  Qed.
End COMPOSE.

Arguments comp_fst {li1 li2 li3 cc12 cc23} w.
Arguments comp_snd {li1 li2 li3 cc12 cc23} w.

Ltac inv_compose_query :=
  let w := fresh "w" in
  let q1 := fresh "q1" in
  let q2 := fresh "q2" in
  let Hq := fresh "Hq" in
  intros w q1 q2 Hq;
  pattern (comp_fst w), (comp_snd w), q1, q2;
  revert w q1 q2 Hq;
  apply match_query_cc_compose.

(** ** Extension passes *)

Definition loc_out_of_bounds (m: mem) (b: block) (ofs: Z) : Prop :=
  ~Mem.perm m b ofs Max Nonempty.

Program Definition cc_extends: callconv li_c li_c :=
  {|
    world_def := unit;
    dummy_world_def := tt;
    match_senv w := eq;
    match_query_def w :=
      fun '(cq id1 sg1 vargs1 m1) '(cq id2 sg2 vargs2 m2) =>
        id1 = id2 /\
        sg1 = sg2 /\
        Val.lessdef_list vargs1 vargs2 /\
        Mem.extends m1 m2;
    match_reply_def w :=
      fun '(cq _ _ _ m1) '(cq _ _ _ m2) '(vres1, m1') '(vres2, m2') =>
        Val.lessdef vres1 vres2 /\
        Mem.extends m1' m2' /\
        Mem.unchanged_on (loc_out_of_bounds m1) m2 m2';
  |}.
Next Obligation.
  intuition.
  apply Mem.extends_refl.
Qed.

Lemma match_cc_extends id sg vargs1 m1 vargs2 m2:
  Mem.extends m1 m2 ->
  Val.lessdef_list vargs1 vargs2 ->
  exists w,
    match_query cc_extends w (cq id sg vargs1 m1) (cq id sg vargs2 m2) /\
    forall vres1 m1' vres2 m2',
      match_reply cc_extends w (vres1, m1') (vres2, m2') ->
      Val.lessdef vres1 vres2 /\
      Mem.extends m1' m2' /\
      Mem.unchanged_on (loc_out_of_bounds m1) m2 m2'.
Proof.
  intros Hm Hvargs.
  assert (Hq: match_query_def _ _ cc_extends tt (cq id sg vargs1 m1) (cq id sg vargs2 m2)).
  {
    simpl.
    eauto.
  }
  exists (mk_world cc_extends tt _ _ Hq).
  split.
  - constructor.
  - intros.
    inv H.
    assumption.
Qed.

(** ** Injection passes *)

Definition symbols_inject (f: meminj) (ge1 ge2: Senv.t): Prop :=
   (forall id, Senv.public_symbol ge2 id = Senv.public_symbol ge1 id)
/\ (forall id b1 b2 delta,
     f b1 = Some(b2, delta) -> Senv.find_symbol ge1 id = Some b1 ->
     delta = 0 /\ Senv.find_symbol ge2 id = Some b2)
/\ (forall id b1,
     Senv.public_symbol ge1 id = true -> Senv.find_symbol ge1 id = Some b1 ->
     exists b2, f b1 = Some(b2, 0) /\ Senv.find_symbol ge2 id = Some b2)
/\ (forall b1 b2 delta,
     f b1 = Some(b2, delta) ->
     Senv.block_is_volatile ge2 b2 = Senv.block_is_volatile ge1 b1).

Definition loc_unmapped (f: meminj) (b: block) (ofs: Z): Prop :=
  f b = None.

Definition loc_out_of_reach (f: meminj) (m: mem) (b: block) (ofs: Z): Prop :=
  forall b0 delta,
  f b0 = Some(b, delta) -> ~Mem.perm m b0 (ofs - delta) Max Nonempty.

Definition inject_separated (f f': meminj) (m1 m2: mem): Prop :=
  forall b1 b2 delta,
  f b1 = None -> f' b1 = Some(b2, delta) ->
  ~Mem.valid_block m1 b1 /\ ~Mem.valid_block m2 b2.

Program Definition cc_inject: callconv li_c li_c :=
  {|
    world_def := meminj;
    dummy_world_def := Mem.flat_inj (Mem.nextblock Mem.empty);
    match_senv := symbols_inject;
    match_query_def f :=
      fun '(cq id1 sg1 vargs1 m1) '(cq id2 sg2 vargs2 m2) =>
        id1 = id2 /\
        sg1 = sg2 /\
        Val.inject_list f vargs1 vargs2 /\
        Mem.inject f m1 m2;
    match_reply_def f :=
      fun '(cq _ _ _ m1) '(cq _ _ _ m2) '(vres1, m1') '(vres2, m2') =>
        exists f',
          Val.inject f' vres1 vres2 /\
          Mem.inject f' m1' m2' /\
          Mem.unchanged_on (loc_unmapped f) m1 m1' /\
          Mem.unchanged_on (loc_out_of_reach f m1) m2 m2' /\
          inject_incr f f' /\
          inject_separated f f' m1 m2;
  |}.
Next Obligation.
  intuition.
  apply (Mem.neutral_inject Mem.empty).
  apply Mem.empty_inject_neutral.
Qed.

Lemma match_cc_inject id sg f vargs1 m1 vargs2 m2:
  Val.inject_list f vargs1 vargs2 ->
  Mem.inject f m1 m2 ->
  exists w,
    match_query cc_inject w (cq id sg vargs1 m1) (cq id sg vargs2 m2) /\
    forall vres1 m1' vres2 m2',
      match_reply cc_inject w (vres1, m1') (vres2, m2') ->
      exists f',
        Val.inject f' vres1 vres2 /\
        Mem.inject f' m1' m2' /\
        Mem.unchanged_on (loc_unmapped f) m1 m1' /\
        Mem.unchanged_on (loc_out_of_reach f m1) m2 m2' /\
        inject_incr f f' /\
        inject_separated f f' m1 m2.
Proof.
  intros Hvargs Hm.
  assert (match_query_def _ _ cc_inject f (cq id sg vargs1 m1) (cq id sg vargs2 m2)).
  {
    simpl.
    eauto.
  }
  exists (mk_world cc_inject _ _ _ H).
  split.
  - econstructor.
  - intros vres1 m1' vres2 m2' Hr.
    inv Hr.
    assumption.
Qed.

(** ** Triangular diagrams *)

(** When proving simulation for initial and final states, we do not
  use the rectangular diagrams of [cc_extends] and [cc_inject]
  directly. Instead, we use triangular diagrams where initial states
  are identical. The execution can still introduce an extension or
  injection, so that final states may be different.

  Because initial states are identical, there is no possibility for
  the target program to modify regions that are present in the target
  initial memory, but not in the source initial memory (for instance,
  the caller's spilling locations. Consequently, the [Mem.unchanged]
  constraints specified in [cc_extends] and [cc_inject] hold
  automatically. This means the simulation relation does not need to
  keep track of these invariants, which simplifies the proof
  significantly.

  The reason this is sufficient is that the triangular diagram is a
  absorbed on the left by the rectangular diagram: for instance, if we
  compose the triangular diagram for injection passes with a proof
  that the target language is compatible with injections, and the
  rectangular diagram can be recovered. *)

(** *** Initial state accessors *)

(** Following CompCertX, our simulation proofs are parametrized over
  the components of the initial state (memory, arguments, etc.).
  These components can be obtained from the outer world used in the
  simulation as follows. *)

Notation tr_id w := (cq_id (world_q1 w)).
Notation tr_sg w := (cq_sg (world_q1 w)).
Notation tr_args w := (cq_args (world_q1 w)).
Notation tr_mem w := (cq_mem (world_q1 w)).

(** *** Extensions *)

Program Definition cc_extends_triangle: callconv li_c li_c :=
  {|
    world_def := unit;
    dummy_world_def := tt;
    match_senv w := eq;
    match_query_def w := eq;
    match_reply_def w :=
      fun _ _ '(vres1, m1') '(vres2, m2') =>
        Val.lessdef vres1 vres2 /\
        Mem.extends m1' m2'
  |}.

(** The following lemma and tactic are used in simulation proofs for
  initial states, as a way to inverse the [match_query] hypothesis.
  See also the [inv_triangle_query] tactic below. *)

Lemma match_query_cc_extends_triangle (P: _ -> _ -> _ -> _ -> _ -> _ -> Prop):
  (forall id sg vargs m,
    P id sg vargs m (cq id sg vargs m) (cq id sg vargs m)) ->
  (forall w q1 q2,
    match_query cc_extends_triangle w q1 q2 ->
    P (tr_id w) (tr_sg w) (tr_args w) (tr_mem w) q1 q2).
Proof.
  intros H w q1 q2 Hq.
  destruct Hq.
  destruct Hq.
  destruct q1.
  apply H; auto.
Qed.

(** The following lemma is used in simulation proofs for final states,
  to show that corresponding replies are related. *)

Lemma match_reply_cc_extends_triangle w vres1 m1' vres2 m2':
  Val.lessdef vres1 vres2 ->
  Mem.extends m1' m2' ->
  match_reply cc_extends_triangle w (vres1, m1') (vres2, m2').
Proof.
  intros.
  destruct w as [f q1 q2 Hq].
  constructor.
  simpl.
  auto.
Qed.

(** *** Injections *)

(** The triangular diagram for injections requires the initial
  memories and arguments to be "inject_neutral". *)

Inductive cc_inject_triangle_mq: meminj -> query li_c -> query li_c -> Prop :=
  cc_inject_triangle_mq_intro id sg vargs m:
    Val.inject_list (Mem.flat_inj (Mem.nextblock m)) vargs vargs ->
    Mem.inject_neutral (Mem.nextblock m) m ->
    cc_inject_triangle_mq
      (Mem.flat_inj (Mem.nextblock m))
      (cq id sg vargs m)
      (cq id sg vargs m).

Program Definition cc_inject_triangle: callconv li_c li_c :=
  {|
    world_def := meminj;
    dummy_world_def := Mem.flat_inj (Mem.nextblock Mem.empty);
    match_senv := symbols_inject;
    match_query_def := cc_inject_triangle_mq;
    match_reply_def f :=
      fun '(cq _ _ _ m1) '(cq _ _ _ m2) '(vres1, m1') '(vres2, m2') =>
        exists f',
          Val.inject f' vres1 vres2 /\
          Mem.inject f' m1' m2' /\
          inject_incr f f' /\
          inject_separated f f' m1 m2;
  |}.
Next Obligation.
  rewrite <- Mem.nextblock_empty.
  constructor; intuition.
  apply Mem.empty_inject_neutral.
Qed.

(** The following lemma is used to prove initial state simulations,
  as a way to inverse the [match_query] hypothesis. See also the
  [inv_triangle_query] tactic below. *)

Lemma match_query_cc_inject_triangle (P: _ -> _ -> _ -> _ -> _ -> _ -> Prop):
  (forall id sg vargs m,
    Val.inject_list (Mem.flat_inj (Mem.nextblock m)) vargs vargs ->
    Mem.inject_neutral (Mem.nextblock m) m ->
    P id sg vargs m (cq id sg vargs m) (cq id sg vargs m)) ->
  (forall w q1 q2,
    match_query cc_inject_triangle w q1 q2 ->
    P (tr_id w) (tr_sg w) (tr_args w) (tr_mem w) q1 q2).
Proof.
  intros H w q1 q2 Hq.
  destruct Hq.
  destruct Hq.
  apply H; auto.
Qed.

(** The following lemma is used in simulation proofs for final states,
  to show that corresponding replies are related. *)

Lemma match_reply_cc_inject_triangle w f' vres1 m1' vres2 m2':
  let m := cq_mem (world_q1 w) in
  let f := Mem.flat_inj (Mem.nextblock m) in
  Val.inject f' vres1 vres2 ->
  Mem.inject f' m1' m2' ->
  inject_incr f f' ->
  inject_separated f f' m m ->
  match_reply cc_inject_triangle w (vres1, m1') (vres2, m2').
Proof.
  intros.
  subst m f.
  destruct w as [f q1 q2 Hq].
  destruct Hq as [id sg vargs m Hvargs Hm].
  simpl in *.
  constructor.
  simpl.
  eauto 10.
Qed.

(** *** Tactics *)

(** This tactic is used to apply the relevant lemma at the beginning
  of initial state simulation proofs. *)

Ltac inv_triangle_query :=
  let w := fresh "w" in
  let q1 := fresh "q1" in
  let q2 := fresh "q2" in
  let Hq := fresh "Hq" in
  intros w q1 q2 Hq;
  pattern (tr_id w), (tr_sg w), (tr_args w), (tr_mem w), q1, q2;
  revert w q1 q2 Hq;
  first
    [ apply match_query_cc_extends_triangle
    | apply match_query_cc_inject_triangle ].
