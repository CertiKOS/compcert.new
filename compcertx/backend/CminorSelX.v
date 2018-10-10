Require compcert.backend.CminorSel.
Require SmallstepX.
Require EventsX.

Import AST.
Import Values.
Import Memory.
Import Globalenvs.
Import EventsX.
Import SmallstepX.
Export CminorSel.

Require Import ZArith.

Section WITHCONFIG.
Context `{external_calls_prf : ExternalCalls}.

Variable fn_stack_requirements: ident -> Z.

(** Execution of RTL functions with C-style arguments (long long 64-bit integers allowed) *)

Inductive initial_state
          fsr (p: CminorSel.program) (i: ident) (m: mem)
          (sg: signature) (args: list val): state -> Prop :=
| initial_state_intro    
    b
    (Hb: Genv.find_symbol (Genv.globalenv p) i = Some b)
    f
    (Hf: Genv.find_funct_ptr (Genv.globalenv p) b = Some f)
    (** We need to keep the signature because it is required for lower-level languages *)
    (Hsig: sg = funsig f)
  :
     initial_state fsr p i m sg args (Callstate f args Kstop (Mem.push_new_stage m) (fsr i))
.

Inductive final_state (sg: signature): state -> (val * mem) -> Prop :=
| final_state_intro
    v
    m m' (USB: Mem.unrecord_stack_block m = Some m'):
    final_state sg (Returnstate v Kstop m) (v, m')
.

(** We define the per-module semantics of RTL as adaptable to both C-style and Asm-style;
    by default it is C-style. *)

Definition semantics fsr
           (p: CminorSel.program) (i: ident) (m: mem)
           (sg: signature) (args: list val) :=
  Semantics
   (CminorSel.step fsr)
    (initial_state fsr p i m sg args) (final_state sg) (Genv.globalenv p).

End WITHCONFIG.
