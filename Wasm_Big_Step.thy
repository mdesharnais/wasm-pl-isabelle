theory Wasm_Big_Step
  imports
    "WebAssembly/Wasm_Properties"
    "Word_Lib.More_Arithmetic"
begin

datatype res_b =
  RValue "v list" 
| RBreak nat "v list"
| RReturn "v list"
| RTrap

inductive reduce_to :: "[(s \<times> v list \<times> e list), (nat list \<times> nat option \<times> inst), (s \<times> v list \<times> res_b)] \<Rightarrow> bool" ("_ \<Down>{_} _" 60) where
  \<comment> \<open>\<open>constant values\<close>\<close>
  emp:"(s,vs,[]) \<Down>{\<Gamma>} (s,vs,RValue [])"
  \<comment> \<open>\<open>unary ops\<close>\<close>
| unop:"(s,vs,[$C v, $(Unop t op)]) \<Down>{\<Gamma>} (s,vs,RValue [(app_unop op v)])"
  \<comment> \<open>\<open>binary ops\<close>\<close>
| binop_Some:"\<lbrakk>app_binop op v1 v2 = (Some v)\<rbrakk> \<Longrightarrow> (s,vs,[$C v1, $C v2, $(Binop t op)]) \<Down>{\<Gamma>} (s,vs,RValue [v])"
| binop_None:"\<lbrakk>app_binop op v1 v2 = None\<rbrakk> \<Longrightarrow> (s,vs,[$C v1, $C v2, $(Binop t op)]) \<Down>{\<Gamma>} (s,vs,RTrap)"
  \<comment> \<open>\<open>testops\<close>\<close>
| testop:"(s,vs,[$C v, $(Testop t op)]) \<Down>{\<Gamma>} (s,vs,RValue [(app_testop op v)])"
  \<comment> \<open>\<open>relops\<close>\<close>
| relop:"(s,vs,[$C v1, $C v2, $(Relop t op)]) \<Down>{\<Gamma>} (s,vs,RValue [(app_relop op v1 v2)])"
  \<comment> \<open>\<open>convert\<close>\<close>
| convert_Some:"\<lbrakk>types_agree t1 v; cvt t2 sx v = (Some v')\<rbrakk> \<Longrightarrow> (s,vs,[$(C v), $(Cvtop t2 Convert t1 sx)]) \<Down>{\<Gamma>} (s,vs,RValue [v'])"
| convert_None:"\<lbrakk>types_agree t1 v; cvt t2 sx v = None\<rbrakk> \<Longrightarrow> (s,vs,[$(C v), $(Cvtop t2 Convert t1 sx)]) \<Down>{\<Gamma>} (s,vs,RTrap)"
  \<comment> \<open>\<open>reinterpret\<close>\<close>
| reinterpret:"types_agree t1 v \<Longrightarrow> (s,vs,[$(C v), $(Cvtop t2 Reinterpret t1 None)]) \<Down>{\<Gamma>} (s,vs,RValue [(wasm_deserialise (bits v) t2)])"
  \<comment> \<open>\<open>unreachable\<close>\<close>
| unreachable:"(s,vs,[$ Unreachable]) \<Down>{\<Gamma>} (s,vs,RTrap)"
  \<comment> \<open>\<open>nop\<close>\<close>
| nop:"(s,vs,[$ Nop]) \<Down>{\<Gamma>} (s,vs,RValue [])"
  \<comment> \<open>\<open>drop\<close>\<close>
| drop:"(s,vs,[$(C v), ($ Drop)]) \<Down>{\<Gamma>} (s,vs,RValue [])"
  \<comment> \<open>\<open>select\<close>\<close>
| select_false:"int_eq n 0 \<Longrightarrow> (s,vs,[$(C v1), $(C v2), $C (ConstInt32 n), ($ Select)]) \<Down>{\<Gamma>} (s,vs, RValue [v2])"
| select_true:"int_ne n 0 \<Longrightarrow> (s,vs,[$(C v1), $(C v2), $C (ConstInt32 n), ($ Select)]) \<Down>{\<Gamma>} (s,vs,RValue [v1])"
  \<comment> \<open>\<open>block\<close>\<close>
| block:"\<lbrakk>const_list ves; length ves = n; length t1s = n; length t2s = m; (s,vs,[Label m [] (ves @ ($* es))]) \<Down>{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves @ [$(Block (t1s _> t2s) es)]) \<Down>{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>loop\<close>\<close>
| loop:"\<lbrakk>const_list ves; length ves = n; length t1s = n; length t2s = m; (s,vs,[Label n [$(Loop (t1s _> t2s) es)] (ves @ ($* es))]) \<Down>{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves @ [$(Loop (t1s _> t2s) es)]) \<Down>{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>if\<close>\<close>
| if_false:"\<lbrakk>int_eq n 0; const_list ves; (s,vs,ves@[$(Block tf e2s)]) \<Down>{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 n), $(If tf e1s e2s)]) \<Down>{\<Gamma>} (s',vs',res)"
| if_true:"\<lbrakk>int_ne n 0; const_list ves; (s,vs,ves@[$(Block tf e1s)]) \<Down>{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 n), $(If tf e1s e2s)]) \<Down>{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>br\<close>\<close>
| br:"\<lbrakk>length vcs = n; k < length ls; ls!k = n\<rbrakk> \<Longrightarrow> (s,vs,(($$*vcs) @ [$(Br k)])) \<Down>{(ls,r,i)} (s,vs,RBreak k vcs)"
  \<comment> \<open>\<open>br_if\<close>\<close>
| br_if_false:"int_eq n 0 \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $(Br_if k)]) \<Down>{\<Gamma>} (s,vs,RValue [])"
| br_if_true:"\<lbrakk>int_ne n 0; const_list ves; (s,vs,ves@[$(Br k)]) \<Down>{\<Gamma>} (s',vs',res) \<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 n), $(Br_if k)]) \<Down>{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>br_table\<close>\<close>
| br_table:"\<lbrakk>length ks > (nat_of_int c); const_list ves; (s,vs,ves@[$(Br (ks!(nat_of_int c)))]) \<Down>{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 c), $(Br_table ks k)]) \<Down>{\<Gamma>} (s',vs',res)"
| br_table_length:"\<lbrakk>length ks \<le> (nat_of_int c); const_list ves; (s,vs,ves@[$(Br k)]) \<Down>{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 c), $(Br_table ks k)]) \<Down>{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>return\<close>\<close>
| return:"\<lbrakk>length vcs = r\<rbrakk>  \<Longrightarrow> (s,vs,($$*vcs) @ [$Return]) \<Down>{(ls,Some r,i)} (s,vs,RReturn vcs)"
  \<comment> \<open>\<open>get_local\<close>\<close>
| get_local:"\<lbrakk>length vi = j\<rbrakk> \<Longrightarrow> (s,(vi @ [v] @ vs),[$(Get_local j)]) \<Down>{\<Gamma>} (s,(vi @ [v] @ vs),RValue [v])"
  \<comment> \<open>\<open>set_local\<close>\<close>
| set_local:"\<lbrakk>length vi = j\<rbrakk> \<Longrightarrow> (s,(vi @ [v] @ vs),[$(C v'), $(Set_local j)]) \<Down>{\<Gamma>} (s,(vi @ [v'] @ vs),RValue [])"
  \<comment> \<open>\<open>tee_local\<close>\<close>
| tee_local:"\<lbrakk>is_const v; (s,vs,[v, v, $(Set_local i)]) \<Down>{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,[v, $(Tee_local i)]) \<Down>{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>get_global\<close>\<close>
| get_global:"(s,vs,[$(Get_global j)]) \<Down>{(ls,r,i)} (s,vs,RValue [(sglob_val s i j)])"
  \<comment> \<open>\<open>set_global\<close>\<close>
| set_global:"supdate_glob s i j v = s' \<Longrightarrow> (s,vs,[$(C v), $(Set_global j)]) \<Down>{(ls,r,i)} (s',vs,RValue [])"
  \<comment> \<open>\<open>load\<close>\<close>
| load_Some:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; load m (nat_of_int k) off (t_length t) = Some bs\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 k), $(Load t None a off)]) \<Down>{(ls,r,i)} (s,vs,RValue [(wasm_deserialise bs t)])"
| load_None:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; load m (nat_of_int k) off (t_length t) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 k), $(Load t None a off)]) \<Down>{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>load packed\<close>\<close>
| load_packed_Some:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; load_packed sx m (nat_of_int k) off (tp_length tp) (t_length t) = Some bs\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 k), $(Load t (Some (tp, sx)) a off)]) \<Down>{(ls,r,i)} (s,vs,RValue [(wasm_deserialise bs t)])"
| load_packed_None:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; load_packed sx m (nat_of_int k) off (tp_length tp) (t_length t) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 k), $(Load t (Some (tp, sx)) a off)]) \<Down>{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>store\<close>\<close>
| store_Some:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store m (nat_of_int k) off (bits v) (t_length t) = Some mem'\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 k), $C v, $(Store t None a off)]) \<Down>{(ls,r,i)} (s\<lparr>mems:= ((mems s)[j := mem'])\<rparr>,vs,RValue [])"
| store_None:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store m (nat_of_int k) off (bits v) (t_length t) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 k), $C v, $(Store t None a off)]) \<Down>{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>store packed\<close>\<close> (* take only (tp_length tp) lower order bytes *)
| store_packed_Some:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store_packed m (nat_of_int k) off (bits v) (tp_length tp) = Some mem'\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 k), $C v, $(Store t (Some tp) a off)]) \<Down>{(ls,r,i)} (s\<lparr>mems:= ((mems s)[j := mem'])\<rparr>,vs,RValue [])"
| store_packed_None:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store_packed m (nat_of_int k) off (bits v) (tp_length tp) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 k), $C v, $(Store t (Some tp) a off)]) \<Down>{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>current_memory\<close>\<close>
| current_memory:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; mem_size m = n\<rbrakk> \<Longrightarrow> (s,vs,[ $(Current_memory)]) \<Down>{(ls,r,i)} (s,vs,RValue [(ConstInt32 (int_of_nat n))])"
  \<comment> \<open>\<open>grow_memory\<close>\<close>
| grow_memory:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; mem_size m = n; mem_grow m (nat_of_int c) = Some mem'\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 c), $(Grow_memory)]) \<Down>{(ls,r,i)} (s\<lparr>mems:= ((mems s)[j := mem'])\<rparr>,vs, RValue [(ConstInt32 (int_of_nat n))])"
  \<comment> \<open>\<open>grow_memory fail\<close>\<close>
| grow_memory_fail:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; mem_size m = n\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 c),$(Grow_memory)]) \<Down>{(ls,r,i)} (s,vs,RValue [(ConstInt32 int32_minus_one)])"
  \<comment> \<open>\<open>call\<close>\<close>
| call:"\<lbrakk>const_list ves; (s,vs,ves@[Invoke (sfunc s i j)]) \<Down>{(ls,r,i)} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$(Call j)]) \<Down>{(ls,r,i)} (s',vs',res)"
  \<comment> \<open>\<open>call_indirect\<close>\<close>
| call_indirect_Some:"\<lbrakk>stab s i (nat_of_int c) = Some cl; stypes s i j = tf; cl_type cl = tf; const_list ves; (s,vs,ves@[Invoke cl]) \<Down>{(ls,r,i)} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 c), $(Call_indirect j)]) \<Down>{(ls,r,i)} (s',vs',res)"
| call_indirect_None:"\<lbrakk>(stab s i (nat_of_int c) = Some cl \<and> stypes s i j \<noteq> cl_type cl) \<or> stab s i (nat_of_int c) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 c), $(Call_indirect j)]) \<Down>{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>call\<close>\<close>
| invoke_native:"\<lbrakk>cl = Func_native j (t1s _> t2s) ts es; ves = ($$* vcs); length vcs = n; length ts = k; length t1s = n; length t2s = m; (n_zeros ts = zs); (s,vs,[Local m j (vcs@zs) [$(Block ([] _> t2s) es)]]) \<Down>{(ls,r,i)} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves @ [Invoke cl]) \<Down>{(ls,r,i)} (s',vs',res)"
| invoke_host_Some:"\<lbrakk>cl = Func_host (t1s _> t2s) f; ves = ($$* vcs); length vcs = n; length t1s = n; length t2s = m; host_apply s (t1s _> t2s) f vcs hs = Some (s', vcs')\<rbrakk> \<Longrightarrow> (s,vs,ves @ [Invoke cl]) \<Down>{(ls,r,i)} (s',vs,RValue vcs')"
| invoke_host_None:"\<lbrakk>cl = Func_host (t1s _> t2s) f; ves = ($$* vcs); length vcs = n; length t1s = n; length t2s = m\<rbrakk> \<Longrightarrow> (s,vs,ves @ [Invoke cl]) \<Down>{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>value congruence\<close>\<close>
| const_value:"\<lbrakk>(s,vs,es) \<Down>{\<Gamma>} (s',vs',RValue res); ves \<noteq> []\<rbrakk> \<Longrightarrow> (s,vs,($$*ves)@es) \<Down>{\<Gamma>} (s',vs',RValue (ves@res))"
| label_value:"\<lbrakk>(s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RValue res)\<rbrakk> \<Longrightarrow> (s,vs,[Label n les es]) \<Down>{(ls,r,i)} (s',vs',RValue res)"
| local_value:"\<lbrakk>(s,lls,es) \<Down>{([],Some n,j)} (s',lls',RValue res)\<rbrakk> \<Longrightarrow> (s,vs,[Local n j lls es]) \<Down>{\<Gamma>} (s',vs,RValue res)"
  \<comment> \<open>\<open>seq congruence\<close>\<close>
| seq_value:"\<lbrakk>(s,vs,es) \<Down>{\<Gamma>} (s'',vs'',RValue res''); (s'',vs'',($$* res'') @ es') \<Down>{\<Gamma>} (s',vs',res); \<not> const_list es; es' \<noteq> []\<rbrakk> \<Longrightarrow> (s,vs,es @ es') \<Down>{\<Gamma>} (s',vs',res)"
| seq_nonvalue1:"\<lbrakk>const_list ves; (s,vs,es) \<Down>{\<Gamma>} (s',vs',res); \<nexists>rvs. res = RValue rvs; ves \<noteq> []; es \<noteq> []\<rbrakk> \<Longrightarrow> (s,vs,ves @ es) \<Down>{\<Gamma>} (s',vs',res)"
| seq_nonvalue2:"\<lbrakk>(s,vs,es) \<Down>{\<Gamma>} (s',vs',res); \<nexists>rvs. res = RValue rvs; es' \<noteq> []\<rbrakk> \<Longrightarrow> (s,vs,es @ es') \<Down>{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>trap congruence\<close>\<close>
| label_trap:"\<lbrakk>(s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RTrap)\<rbrakk> \<Longrightarrow> (s,vs,[Label n les es]) \<Down>{(ls,r,i)} (s',vs',RTrap)"
| local_trap:"\<lbrakk>(s,lls,es) \<Down>{([],Some n,j)} (s',lls',RTrap)\<rbrakk> \<Longrightarrow> (s,vs,[Local n j lls es]) \<Down>{\<Gamma>} (s',vs,RTrap)"
  \<comment> \<open>\<open>break congruence\<close>\<close>
| label_break_suc:"\<lbrakk>(s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RBreak (Suc bn) bvs)\<rbrakk> \<Longrightarrow> (s,vs,[Label n les es]) \<Down>{(ls,r,i)} (s',vs',RBreak bn bvs)"
| label_break_nil:"\<lbrakk>(s,vs,es) \<Down>{(n#ls,r,i)} (s'',vs'',RBreak 0 bvs); (s'',vs'',($$*(vcs @ bvs)) @ les) \<Down>{(ls,r,i)} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,($$*vcs)@[Label n les es]) \<Down>{(ls,r,i)} (s',vs',res)"
  \<comment> \<open>\<open>return congruence\<close>\<close>
| label_return:"\<lbrakk>(s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RReturn rvs)\<rbrakk> \<Longrightarrow> (s,vs,[Label n les es]) \<Down>{(ls,r,i)} (s',vs',RReturn rvs)"
| local_return:"\<lbrakk>(s,lls,es) \<Down>{([],Some n,j)} (s',lls',RReturn rvs)\<rbrakk> \<Longrightarrow> (s,vs,[Local n j lls es]) \<Down>{\<Gamma>} (s',vs,RValue rvs)"
  \<comment> \<open>\<open>trap\<close>\<close>
| trap:"(s,vs,[Trap]) \<Down>{\<Gamma>} (s,vs,RTrap)"

inductive reduce_to_n :: "[(s \<times> v list \<times> e list), nat, (nat list \<times> nat option \<times> inst), (s \<times> v list \<times> res_b)] \<Rightarrow> bool" ("_ \<Down>_{_} _" 60) where
  \<comment> \<open>\<open>constant values\<close>\<close>
  emp:"(s,vs,[]) \<Down>k{\<Gamma>} (s,vs,RValue [])"
  \<comment> \<open>\<open>unary ops\<close>\<close>
| unop:"(s,vs,[$C v, $(Unop t op)]) \<Down>k{\<Gamma>} (s,vs,RValue [(app_unop op v)])"
  \<comment> \<open>\<open>binary ops\<close>\<close>
| binop_Some:"\<lbrakk>app_binop op v1 v2 = (Some v)\<rbrakk> \<Longrightarrow> (s,vs,[$C v1, $C v2, $(Binop t op)]) \<Down>k{\<Gamma>} (s,vs,RValue [v])"
| binop_None:"\<lbrakk>app_binop op v1 v2 = None\<rbrakk> \<Longrightarrow> (s,vs,[$C v1, $C v2, $(Binop t op)]) \<Down>k{\<Gamma>} (s,vs,RTrap)"
  \<comment> \<open>\<open>testops\<close>\<close>
| testop:"(s,vs,[$C v, $(Testop t op)]) \<Down>k{\<Gamma>} (s,vs,RValue [(app_testop op v)])"
  \<comment> \<open>\<open>relops\<close>\<close>
| relop:"(s,vs,[$C v1, $C v2, $(Relop t op)]) \<Down>k{\<Gamma>} (s,vs,RValue [(app_relop op v1 v2)])"
  \<comment> \<open>\<open>convert\<close>\<close>
| convert_Some:"\<lbrakk>types_agree t1 v; cvt t2 sx v = (Some v')\<rbrakk> \<Longrightarrow> (s,vs,[$(C v), $(Cvtop t2 Convert t1 sx)]) \<Down>k{\<Gamma>} (s,vs,RValue [v'])"
| convert_None:"\<lbrakk>types_agree t1 v; cvt t2 sx v = None\<rbrakk> \<Longrightarrow> (s,vs,[$(C v), $(Cvtop t2 Convert t1 sx)]) \<Down>k{\<Gamma>} (s,vs,RTrap)"
  \<comment> \<open>\<open>reinterpret\<close>\<close>
| reinterpret:"types_agree t1 v \<Longrightarrow> (s,vs,[$(C v), $(Cvtop t2 Reinterpret t1 None)]) \<Down>k{\<Gamma>} (s,vs,RValue [(wasm_deserialise (bits v) t2)])"
  \<comment> \<open>\<open>unreachable\<close>\<close>
| unreachable:"(s,vs,[$ Unreachable]) \<Down>k{\<Gamma>} (s,vs,RTrap)"
  \<comment> \<open>\<open>nop\<close>\<close>
| nop:"(s,vs,[$ Nop]) \<Down>k{\<Gamma>} (s,vs,RValue [])"
  \<comment> \<open>\<open>drop\<close>\<close>
| drop:"(s,vs,[$(C v), ($ Drop)]) \<Down>k{\<Gamma>} (s,vs,RValue [])"
  \<comment> \<open>\<open>select\<close>\<close>
| select_false:"int_eq n 0 \<Longrightarrow> (s,vs,[$(C v1), $(C v2), $C (ConstInt32 n), ($ Select)]) \<Down>k{\<Gamma>} (s,vs, RValue [v2])"
| select_true:"int_ne n 0 \<Longrightarrow> (s,vs,[$(C v1), $(C v2), $C (ConstInt32 n), ($ Select)]) \<Down>k{\<Gamma>} (s,vs,RValue [v1])"
  \<comment> \<open>\<open>block\<close>\<close>
| block:"\<lbrakk>const_list ves; length ves = n; length t1s = n; length t2s = m; (s,vs,[Label m [] (ves @ ($* es))]) \<Down>k{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves @ [$(Block (t1s _> t2s) es)]) \<Down>k{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>loop\<close>\<close>
| loop:"\<lbrakk>const_list ves; length ves = n; length t1s = n; length t2s = m; (s,vs,[Label n [$(Loop (t1s _> t2s) es)] (ves @ ($* es))]) \<Down>k{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves @ [$(Loop (t1s _> t2s) es)]) \<Down>k{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>if\<close>\<close>
| if_false:"\<lbrakk>int_eq n 0; const_list ves; (s,vs,ves@[$(Block tf e2s)]) \<Down>k{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 n), $(If tf e1s e2s)]) \<Down>k{\<Gamma>} (s',vs',res)"
| if_true:"\<lbrakk>int_ne n 0; const_list ves; (s,vs,ves@[$(Block tf e1s)]) \<Down>k{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 n), $(If tf e1s e2s)]) \<Down>k{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>br\<close>\<close>
| br:"\<lbrakk>length vcs = n; j < length ls; ls!j = n\<rbrakk> \<Longrightarrow> (s,vs,(($$*vcs) @ [$(Br j)])) \<Down>k{(ls,r,i)} (s,vs,RBreak j vcs)"
  \<comment> \<open>\<open>br_if\<close>\<close>
| br_if_false:"int_eq n 0 \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $(Br_if j)]) \<Down>k{\<Gamma>} (s,vs,RValue [])"
| br_if_true:"\<lbrakk>int_ne n 0; const_list ves; (s,vs,ves@[$(Br j)]) \<Down>k{\<Gamma>} (s',vs',res) \<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 n), $(Br_if j)]) \<Down>k{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>br_table\<close>\<close>
| br_table:"\<lbrakk>length js > (nat_of_int c); const_list ves; (s,vs,ves@[$(Br (js!(nat_of_int c)))]) \<Down>k{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 c), $(Br_table js j)]) \<Down>k{\<Gamma>} (s',vs',res)"
| br_table_length:"\<lbrakk>length js \<le> (nat_of_int c); const_list ves; (s,vs,ves@[$(Br j)]) \<Down>k{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 c), $(Br_table js j)]) \<Down>k{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>return\<close>\<close>
| return:"\<lbrakk>length vcs = r\<rbrakk>  \<Longrightarrow> (s,vs,($$*vcs) @ [$Return]) \<Down>k{(ls,Some r,i)} (s,vs,RReturn vcs)"
  \<comment> \<open>\<open>get_local\<close>\<close>
| get_local:"\<lbrakk>length vi = j\<rbrakk> \<Longrightarrow> (s,(vi @ [v] @ vs),[$(Get_local j)]) \<Down>k{\<Gamma>} (s,(vi @ [v] @ vs),RValue [v])"
  \<comment> \<open>\<open>set_local\<close>\<close>
| set_local:"\<lbrakk>length vi = j\<rbrakk> \<Longrightarrow> (s,(vi @ [v] @ vs),[$(C v'), $(Set_local j)]) \<Down>k{\<Gamma>} (s,(vi @ [v'] @ vs),RValue [])"
  \<comment> \<open>\<open>tee_local\<close>\<close>
| tee_local:"\<lbrakk>is_const v; (s,vs,[v, v, $(Set_local i)]) \<Down>k{\<Gamma>} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,[v, $(Tee_local i)]) \<Down>k{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>get_global\<close>\<close>
| get_global:"(s,vs,[$(Get_global j)]) \<Down>k{(ls,r,i)} (s,vs,RValue [(sglob_val s i j)])"
  \<comment> \<open>\<open>set_global\<close>\<close>
| set_global:"supdate_glob s i j v = s' \<Longrightarrow> (s,vs,[$(C v), $(Set_global j)]) \<Down>k{(ls,r,i)} (s',vs,RValue [])"
  \<comment> \<open>\<open>load\<close>\<close>
| load_Some:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; load m (nat_of_int n) off (t_length t) = Some bs\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $(Load t None a off)]) \<Down>k{(ls,r,i)} (s,vs,RValue [(wasm_deserialise bs t)])"
| load_None:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; load m (nat_of_int n) off (t_length t) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $(Load t None a off)]) \<Down>k{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>load packed\<close>\<close>
| load_packed_Some:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; load_packed sx m (nat_of_int n) off (tp_length tp) (t_length t) = Some bs\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $(Load t (Some (tp, sx)) a off)]) \<Down>k{(ls,r,i)} (s,vs,RValue [(wasm_deserialise bs t)])"
| load_packed_None:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; load_packed sx m (nat_of_int n) off (tp_length tp) (t_length t) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $(Load t (Some (tp, sx)) a off)]) \<Down>k{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>store\<close>\<close>
| store_Some:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store m (nat_of_int n) off (bits v) (t_length t) = Some mem'\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $C v, $(Store t None a off)]) \<Down>k{(ls,r,i)} (s\<lparr>mems:= ((mems s)[j := mem'])\<rparr>,vs,RValue [])"
| store_None:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store m (nat_of_int n) off (bits v) (t_length t) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $C v, $(Store t None a off)]) \<Down>k{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>store packed\<close>\<close> (* take only (tp_length tp) lower order bytes *)
| store_packed_Some:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store_packed m (nat_of_int n) off (bits v) (tp_length tp) = Some mem'\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $C v, $(Store t (Some tp) a off)]) \<Down>k{(ls,r,i)} (s\<lparr>mems:= ((mems s)[j := mem'])\<rparr>,vs,RValue [])"
| store_packed_None:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store_packed m (nat_of_int n) off (bits v) (tp_length tp) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $C v, $(Store t (Some tp) a off)]) \<Down>k{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>current_memory\<close>\<close>
| current_memory:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; mem_size m = n\<rbrakk> \<Longrightarrow> (s,vs,[ $(Current_memory)]) \<Down>k{(ls,r,i)} (s,vs,RValue [(ConstInt32 (int_of_nat n))])"
  \<comment> \<open>\<open>grow_memory\<close>\<close>
| grow_memory:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; mem_size m = n; mem_grow m (nat_of_int c) = Some mem'\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 c), $(Grow_memory)]) \<Down>k{(ls,r,i)} (s\<lparr>mems:= ((mems s)[j := mem'])\<rparr>,vs, RValue [(ConstInt32 (int_of_nat n))])"
  \<comment> \<open>\<open>grow_memory fail\<close>\<close>
| grow_memory_fail:"\<lbrakk>smem_ind s i = Some j; ((mems s)!j) = m; mem_size m = n\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 c),$(Grow_memory)]) \<Down>k{(ls,r,i)} (s,vs,RValue [(ConstInt32 int32_minus_one)])"
  \<comment> \<open>\<open>call\<close>\<close>
| call:"\<lbrakk>const_list ves; (s,vs,ves@[Invoke (sfunc s i j)]) \<Down>k{(ls,r,i)} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$(Call j)]) \<Down>(Suc k){(ls,r,i)} (s',vs',res)"
  \<comment> \<open>\<open>call_indirect\<close>\<close>
| call_indirect_Some:"\<lbrakk>stab s i (nat_of_int c) = Some cl; stypes s i j = tf; cl_type cl = tf; const_list ves; (s,vs,ves@[Invoke cl]) \<Down>k{(ls,r,i)} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves@[$C (ConstInt32 c), $(Call_indirect j)]) \<Down>k{(ls,r,i)} (s',vs',res)"
| call_indirect_None:"\<lbrakk>(stab s i (nat_of_int c) = Some cl \<and> stypes s i j \<noteq> cl_type cl) \<or> stab s i (nat_of_int c) = None\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 c), $(Call_indirect j)]) \<Down>k{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>call\<close>\<close>
| invoke_native:"\<lbrakk>cl = Func_native j (t1s _> t2s) ts es; ves = ($$* vcs); length vcs = n; length t1s = n; length t2s = m; (n_zeros ts = zs); (s,vs,[Local m j (vcs@zs) [$(Block ([] _> t2s) es)]]) \<Down>k{(ls,r,i)} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,ves @ [Invoke cl]) \<Down>k{(ls,r,i)} (s',vs',res)"
| invoke_host_Some:"\<lbrakk>cl = Func_host (t1s _> t2s) f; ves = ($$* vcs); length vcs = n; length t1s = n; length t2s = m; host_apply s (t1s _> t2s) f vcs hs = Some (s', vcs')\<rbrakk> \<Longrightarrow> (s,vs,ves @ [Invoke cl]) \<Down>k{(ls,r,i)} (s',vs,RValue vcs')"
| invoke_host_None:"\<lbrakk>cl = Func_host (t1s _> t2s) f; ves = ($$* vcs); length vcs = n; length t1s = n; length t2s = m\<rbrakk> \<Longrightarrow> (s,vs,ves @ [Invoke cl]) \<Down>k{(ls,r,i)} (s,vs,RTrap)"
  \<comment> \<open>\<open>value congruence\<close>\<close>
| const_value:"\<lbrakk>(s,vs,es) \<Down>k{\<Gamma>} (s',vs',RValue res); ves \<noteq> []\<rbrakk> \<Longrightarrow> (s,vs,($$*ves)@es) \<Down>k{\<Gamma>} (s',vs',RValue (ves@res))"
| label_value:"\<lbrakk>(s,vs,es) \<Down>k{(n#ls,r,i)} (s',vs',RValue res)\<rbrakk> \<Longrightarrow> (s,vs,[Label n les es]) \<Down>k{(ls,r,i)} (s',vs',RValue res)"
| local_value:"\<lbrakk>(s,lls,es) \<Down>k{([],Some n,j)} (s',lls',RValue res)\<rbrakk> \<Longrightarrow> (s,vs,[Local n j lls es]) \<Down>k{\<Gamma>} (s',vs,RValue res)"
  \<comment> \<open>\<open>seq congruence\<close>\<close>
| seq_value:"\<lbrakk>(s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue res''); (s'',vs'',($$* res'') @ es') \<Down>k{\<Gamma>} (s',vs',res); \<not> const_list es; es' \<noteq> []\<rbrakk> \<Longrightarrow> (s,vs,es @ es') \<Down>k{\<Gamma>} (s',vs',res)"
| seq_nonvalue1:"\<lbrakk>const_list ves; (s,vs,es) \<Down>k{\<Gamma>} (s',vs',res); \<nexists>rvs. res = RValue rvs; ves \<noteq> []; es \<noteq> []\<rbrakk> \<Longrightarrow> (s,vs,ves @ es) \<Down>k{\<Gamma>} (s',vs',res)"
| seq_nonvalue2:"\<lbrakk>(s,vs,es) \<Down>k{\<Gamma>} (s',vs',res); \<nexists>rvs. res = RValue rvs; es' \<noteq> []\<rbrakk> \<Longrightarrow> (s,vs,es @ es') \<Down>k{\<Gamma>} (s',vs',res)"
  \<comment> \<open>\<open>trap congruence\<close>\<close>
| label_trap:"\<lbrakk>(s,vs,es) \<Down>k{(n#ls,r,i)} (s',vs',RTrap)\<rbrakk> \<Longrightarrow> (s,vs,[Label n les es]) \<Down>k{(ls,r,i)} (s',vs',RTrap)"
| local_trap:"\<lbrakk>(s,lls,es) \<Down>k{([],Some n,j)} (s',lls',RTrap)\<rbrakk> \<Longrightarrow> (s,vs,[Local n j lls es]) \<Down>k{\<Gamma>} (s',vs,RTrap)"
  \<comment> \<open>\<open>break congruence\<close>\<close>
| label_break_suc:"\<lbrakk>(s,vs,es) \<Down>k{(n#ls,r,i)} (s',vs',RBreak (Suc bn) bvs)\<rbrakk> \<Longrightarrow> (s,vs,[Label n les es]) \<Down>k{(ls,r,i)} (s',vs',RBreak bn bvs)"
| label_break_nil:"\<lbrakk>(s,vs,es) \<Down>k{(n#ls,r,i)} (s'',vs'',RBreak 0 bvs); (s'',vs'',($$*(vcs @ bvs)) @ les) \<Down>k{(ls,r,i)} (s',vs',res)\<rbrakk> \<Longrightarrow> (s,vs,($$*vcs)@[Label n les es]) \<Down>k{(ls,r,i)} (s',vs',res)"
  \<comment> \<open>\<open>return congruence\<close>\<close>
| label_return:"\<lbrakk>(s,vs,es) \<Down>k{(n#ls,r,i)} (s',vs',RReturn rvs)\<rbrakk> \<Longrightarrow> (s,vs,[Label n les es]) \<Down>k{(ls,r,i)} (s',vs',RReturn rvs)"
| local_return:"\<lbrakk>(s,lls,es) \<Down>k{([],Some n,j)} (s',lls',RReturn rvs)\<rbrakk> \<Longrightarrow> (s,vs,[Local n j lls es]) \<Down>k{\<Gamma>} (s',vs,RValue rvs)"
  \<comment> \<open>\<open>trap\<close>\<close>
| trap:"(s,vs,[Trap]) \<Down>k{\<Gamma>} (s,vs,RTrap)"

lemma reduce_to_n_mono:
  assumes "(c1 \<Down>k{\<Gamma>} c2)"
  shows"\<forall>k' \<ge> k. (c1 \<Down>k'{\<Gamma>} c2)"
  using assms
proof (induction rule: reduce_to_n.induct)
  case (call ves s vs i j k ls r s' vs' res)
  thus ?case
    using reduce_to_n.call
    by (metis Suc_le_D Suc_le_lessD less_Suc_eq_le)
qed (fastforce intro: reduce_to_n.intros)+

lemma reduce_to_imp_reduce_to_n:
  assumes "(c1 \<Down>{\<Gamma>} c2)"
  shows"(\<exists>k. (c1 \<Down>k{\<Gamma>} c2))"
  using assms
proof (induction rule: reduce_to.induct)
  case (seq_value s vs es \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using reduce_to_n_mono reduce_to_n.seq_value
    by (meson le_cases)
next
  case (label_break_nil s vs es n ls r i s'' vs'' bvs les s' vs' res)
  thus ?case
    using reduce_to_n_mono reduce_to_n.label_break_nil
    by (meson le_cases)
next
qed (fastforce intro: reduce_to_n.intros)+

lemma reduce_to_n_imp_reduce_to:
  assumes "(c1 \<Down>k{\<Gamma>} c2)"
  shows"(c1 \<Down>{\<Gamma>} c2)"
  using assms
  apply (induction rule: reduce_to_n.induct)
                      apply (fastforce intro: reduce_to.intros)+
  done

lemma reduce_to_iff_reduce_to_n: "(c1 \<Down>{\<Gamma>} c2) = (\<exists>k. (c1 \<Down>k{\<Gamma>} c2))"
  using reduce_to_imp_reduce_to_n reduce_to_n_imp_reduce_to
  by blast

lemma reduce_to_n_emp:
  assumes "(s,vs,[]) \<Down>k{\<Gamma>} (s',vs',res)"
  shows "res = RValue []"
  using assms
  apply (induction "(s,vs,[]::e list)" k \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res rule: reduce_to_n.induct)
                  apply auto
  done

lemma reduce_to_n_consts1: "((s,vs,($$*ves)) \<Down>k{\<Gamma>} (s,vs,RValue ves))"
  using reduce_to_n.emp reduce_to_n.const_value reduce_to_n.emp
  apply (cases "ves = []")
  apply simp_all
  apply (metis append.right_neutral)
  done

lemma reduce_to_consts:
  assumes "((s,vs,($$*ves)) \<Down>{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue ves"
  using assms
proof (induction "(s,vs,($$*ves))""\<Gamma>" "(s',vs',res)" arbitrary: s vs ves s' vs' res rule: reduce_to.induct)
  case (block ves n t1s t2s m es \<Gamma>)
  thus ?case
    using consts_cons_last(2) e_type_const_unwrap
    by blast
next
  case (loop ves n t1s t2s m es \<Gamma>)
  thus ?case
    using consts_cons_last(2) e_type_const_unwrap
    by blast
next
  case (if_false n ves tf e2s \<Gamma> e1s)
  thus ?case
    using consts_cons_last2(3) e_type_const_unwrap
    by (metis b_e.distinct(325) e.inject(1))
next
  case (if_true n ves tf e1s \<Gamma> e2s)
  thus ?case
    using consts_cons_last2(3) e_type_const_unwrap
    by (metis b_e.distinct(325) e.inject(1))
next
  case (br vcs n k ls r i)
  thus ?case
    using consts_cons_last(2) e_type_const_unwrap
    by auto
next
  case (br_if_true n ves k \<Gamma>)
  thus ?case
    using consts_cons_last2(3) e_type_const_unwrap                                   
    by (metis b_e.distinct(403) e.inject(1))
next
  case (br_table ks c ves \<Gamma> k)
  thus ?case
    using consts_cons_last2(3) e_type_const_unwrap
    by (metis b_e.distinct(439) e.inject(1))
next
  case (br_table_length ks c ves k \<Gamma>)
  thus ?case
    using consts_cons_last2(3) e_type_const_unwrap
    by (metis b_e.distinct(439) e.inject(1))
next
  case (return r vcs ls i)
  thus ?case
    using consts_cons_last(2) e_type_const_unwrap
    by auto
next
  case (call ves i j ls r)
  thus ?case
    using consts_cons_last(2) e_type_const_unwrap
    by blast
next
  case (call_indirect_Some i c cl j tf ves ls r)
  thus ?case
    using consts_cons_last2(3) e_type_const_unwrap
    by (metis b_e.distinct(535) e.inject(1))
next
  case (invoke_native cl j t1s t2s ts es ves vcs n k m zs ls r i)
  thus ?case
    using consts_cons_last(2) e_type_const_unwrap
    by blast
next
  case (invoke_host_Some cl t1s t2s f ves vcs n m hs vcs' ls r i)
  thus ?case
    using consts_cons_last(2) e_type_const_unwrap
    by auto
next
  case (const_value s vs es \<Gamma> s' vs' res ves)
  thus ?case
    by (metis consts_app_ex(2) inj_basic_econst map_append map_injective res_b.inject(1))
next
  case (invoke_host_None cl t1s t2s f ves vcs n m ls r i)
  thus ?case
    using consts_cons_last(2) e_type_const_unwrap
    by auto
next
  case (seq_value s vs es \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_ex(1)
    by blast
next
  case (seq_nonvalue1 ves s vs es \<Gamma> s' vs' res)
  thus ?case
    using consts_app_ex
    by meson
next
  case (seq_nonvalue2 s vs es \<Gamma> s' vs' res es' ves)
  thus ?case
    using consts_app_ex
    by meson
next
  case (label_break_nil s vs es n ls r i s'' vs'' bvs vcs les s' vs' res)
  thus ?case
    using consts_app_ex
    by (metis consts_cons_last(2) e.simps(10) e_type_const_unwrap)
qed auto

lemma reduce_to_break_n:
  assumes "(s,vs,es) \<Down>{(ls,r,i)} (s',vs',RBreak n vbs)"
  shows "ls!n = length vbs"
        "n < length ls"
  using assms
  apply (induction "(s,vs,es)" "(ls,r,i)" "(s',vs',RBreak n vbs)" arbitrary: s vs es s' vs' ls n rule: reduce_to.induct)
  apply auto
  done

lemma reduce_to_n_break_n:
  assumes "(s,vs,es) \<Down>k{(ls,r,i)} (s',vs',RBreak n vbs)"
  shows "ls!n = length vbs"
        "n < length ls"
  using reduce_to_break_n assms
  by (meson reduce_to_n_imp_reduce_to)+

lemma reduce_to_return:
  assumes "(s,vs,es) \<Down>{(ls,r,i)} (s',vs',RReturn vrs)"
  shows "\<exists>r_r. r = Some r_r \<and> r_r = length vrs"
  using assms
  apply (induction "(s,vs,es)" "(ls,r,i)" "(s',vs',RReturn vrs)" arbitrary: s vs es s' vs' ls rule: reduce_to.induct)
  apply auto
  done

lemma reduce_to_n_return1:
  assumes "(s,vs,es) \<Down>k{(ls,r,i)} (s',vs',RReturn vrs)"
  shows "\<exists>r_r. r = Some r_r \<and> r_r = length vrs"
  using reduce_to_return assms
  by (meson reduce_to_n_imp_reduce_to)

lemma reduce_to_single_helper1:
  assumes "($$*ves)@es = [e]"
          "\<not>is_const e"
  shows "ves = []"
  using assms
  by (metis Nil_is_append_conv Nil_is_map_conv append_self_conv butlast.simps(2) butlast_append consts_cons(2))
  
lemma reduce_to_trap:
  assumes "((s,vs,[Trap]) \<Down>{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RTrap"
  using assms
proof (induction "(s,vs,[Trap])" "\<Gamma>" "(s',vs',res)" arbitrary: s vs s' vs' res rule: reduce_to.induct)
  case (const_value s vs es \<Gamma> s' vs' res ves)
  thus ?case
    using reduce_to_single_helper1
    by (simp add: is_const_def)
next
  case (seq_value s vs es \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    apply simp
    apply (metis consts_app_snoc is_const_list list.simps(8) self_append_conv2)
    done
next
  case (seq_nonvalue1 ves s vs es \<Gamma> s' vs' res)
  thus ?case
    by (simp add: append_eq_Cons_conv)
next
  case (seq_nonvalue2 s vs es \<Gamma> s' vs' res es')
  thus ?case
    apply simp
    apply (metis (no_types, hide_lams) Cons_eq_append_conv Nil_is_append_conv reduce_to_imp_reduce_to_n reduce_to_n_emp)
    done
qed auto

lemma reduce_to_consts1: "((s,vs,($$*ves)) \<Down>{\<Gamma>} (s,vs,RValue ves))"
  using reduce_to.emp reduce_to.const_value reduce_to.emp
  apply (cases "ves = []")
  apply simp_all
  apply (metis append.right_neutral)
  done

lemma reduce_to_n_consts:
  assumes "((s,vs,($$*ves)) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue ves"
  using assms reduce_to_consts reduce_to_n_imp_reduce_to
  by blast

lemma call0: "((s,vs,($$*ves)@[$(Call j)]) \<Down>0{\<Gamma>} (s',vs',res)) \<Longrightarrow> False"
proof (induction "(s,vs,($$*ves)@[$(Call j)])" "0::nat" \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res ves rule: reduce_to_n.induct)
  case (const_value s vs es \<Gamma> s' vs' res ves ves')
  consider (1) "es = []" | (2) "\<exists>ves'. es = ($$* ves') @ [$Call j]"
    using consts_cons_last consts_app_ex const_value(3)
    by (metis const_value.hyps(4) consts_app_snoc)
  thus ?case
    using const_value
    apply (cases)
    apply (metis append_Nil2 b_e.distinct(505) const_list_cons_last(2) e.inject(1) e_type_const_unwrap is_const_list)
    apply blast
    done
next
  case (seq_value s vs es \<Gamma> s'' vs'' res'' es' s' vs' res)
  consider (1) "es' = []" | (2) "\<exists>ves'. es' = ($$* ves') @ [$Call j]"
    using consts_cons_last consts_app_ex seq_value(7)
    by (metis consts_app_snoc seq_value.hyps(6))
  thus ?case
    using seq_value
    apply (cases)
    apply fastforce
    apply (metis append_assoc map_append)
    done
next
  case (seq_nonvalue1 ves s vs es \<Gamma> s' vs' res)
  thus ?case
    by (metis consts_app_snoc)
next
  case (seq_nonvalue2 s vs es \<Gamma> s' vs' res es' ves)
  thus ?case
    by (metis consts_app_snoc reduce_to_consts reduce_to_n_imp_reduce_to)
qed (fastforce intro: reduce_to_n.intros)+

lemma reduce_to_n_current_memory:
  assumes "((s,vs,($$*ves)@[$Current_memory]) \<Down>k{(ls,r,i)} (s',vs',res))"
  shows "\<exists>n j m. s = s' \<and> vs = vs' \<and> res = RValue (ves@[ConstInt32 (int_of_nat n)]) \<and> smem_ind s i = Some j \<and> ((mems s)!j) = m \<and> mem_size m = n"
  using assms
proof (induction "(s,vs,($$*ves)@[$Current_memory])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k s' vs' res ves)
  consider (1) "es = []" | (2) "\<exists>ves'. es = ($$* ves') @ [$Current_memory]"
    using consts_app_snoc[OF const_value(4)]
    by fastforce
  thus ?case
  proof (cases)
    case 1
    thus ?thesis
      by (metis append_Nil2 b_e.distinct(703) const_value.hyps(3) const_value.hyps(4) e.inject(1) last_map last_snoc)
  next
    case 2
    thus ?thesis
      using const_value
      by (metis (no_types, lifting) append.assoc append1_eq_conv inj_basic_econst map_append map_injective res_b.inject(1))
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    apply simp
    apply (metis (no_types, lifting) reduce_to_n_consts res_b.inject(1))
    done
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  thus ?case
    by (metis consts_app_snoc)
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    by (metis consts_app_snoc reduce_to_n_consts)
qed auto

lemma no_reduce_to_n:
  assumes "(s, vs, [e]) \<Down>k{\<Gamma>} (s', vs', res)"
          "(e = $Unop t uop) \<or> (e = $Testop t testop) \<or> (e = $Binop t bop) \<or> (e = $Relop t rop) \<or>
           (e = $(Cvtop t2 cvtop t1 sx)) \<or> (e = $Drop) \<or> (e = $Select) \<or> (e = $Br_if j) \<or> (e = $Br_table js j) \<or>
           (e = $Set_local j) \<or> (e = $Tee_local j) \<or> (e = $Set_global j) \<or> (e = $Load t tp_sx a off) \<or>
           (e = $Store t tp a off) \<or> (e = $If tf es1 es2)"
  shows False
  using assms
proof (induction "(s,vs,[e])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs s' vs' res k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves)
  thus ?case
    using e_type_const_unwrap consts_cons(2)
    apply safe
            apply simp_all
    apply (metis append_eq_Cons_conv b_e.distinct(727) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.distinct(731) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.distinct(729) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.distinct(733) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.distinct(735) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.simps(167) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.distinct(193) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.simps(425) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.simps(461) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.distinct(589) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.distinct(613) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.distinct(655) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.simps(695) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.simps(711) e.inject(1))
    apply (metis append_eq_Cons_conv b_e.simps(347) e.inject(1))
    done
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    by (metis Cons_eq_append_conv append.right_neutral append_is_Nil_conv consts_app_ex(2) is_const_list)
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  thus ?case
    by (metis Cons_eq_append_conv Nil_is_append_conv)
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    by (metis append_is_Nil_conv butlast.simps(2) butlast_append reduce_to_n_emp)
qed auto

lemma no_reduce_to_n2:
  assumes "(s, vs, [$C v, e]) \<Down>k{\<Gamma>} (s', vs', res)"
          "(e = $Binop t bop) \<or> (e = $Relop t rop) \<or> (e = $Select) \<or> (e = $Store t tp a off)"
  shows False
proof -
  have 0:"\<not>is_const e"
    using assms(2)
    by (auto simp add: is_const_def)
  show ?thesis
    using assms
  proof (induction "(s,vs,[$C v, e])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs s' vs' res k rule: reduce_to_n.induct)
    case (const_value s vs es k \<Gamma> s' vs' res ves)
    hence "es = [e]"
      using consts_app_snoc_1[OF _ 0, of ves es "[]" v]
      by simp
    thus ?thesis
      using no_reduce_to_n const_value(1) assms(2)
      by metis
  next
    case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
    thus ?case
      by (metis 0 append_self_conv2 consts_app_snoc_1_const_list list.simps(8))
  next
    case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
    hence "es = [e]"
      using consts_app_snoc[of ves es "[v]" "e"] 0
      by (metis append_Cons append_is_Nil_conv butlast.simps(2) butlast_append list.simps(8,9) self_append_conv2)
    thus ?thesis
      using no_reduce_to_n seq_nonvalue1(2) assms(2)
      by metis
  next
    case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
    thus ?thesis
      using consts_app_snoc[of es es' "[v]" "e"]
      apply simp
      apply (metis reduce_to_n_consts)
      done
  qed auto
qed

lemma no_reduce_to_n3:
  assumes "(s, vs, [$C v1, $C v2, e]) \<Down>k{\<Gamma>} (s', vs', res)"
          "(e = $Select)"
  shows False
proof -
  have 0:"\<not>is_const e"
    using assms(2)
    by (auto simp add: is_const_def)
  show ?thesis
    using assms
  proof (induction "(s,vs,[$C v1, $C v2, e])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs s' vs' res k rule: reduce_to_n.induct)
    case (const_value s vs es k \<Gamma> s' vs' res ves)
    hence "es = [e] \<or> es = [$C v2, e]"
      using consts_app_snoc_2[OF _ 0, of ves es "[]" v1 v2]
      by auto
    thus ?thesis
      using no_reduce_to_n no_reduce_to_n2 const_value(1) assms(2)
      by metis
  next
    case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
    thus ?case
      by (metis "0" append_self_conv2 consts_app_snoc_2_const_list list.simps(8))
  next
    case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
    hence "es = [e] \<or> es = [$C v2, e]"
      using consts_app_snoc_2[OF _ 0, of _ es "[]" v1 v2]
      by (metis Nil_is_map_conv append_eq_append_conv2 append_is_Nil_conv e_type_const_conv_vs)
    thus ?thesis
      using no_reduce_to_n no_reduce_to_n2 seq_nonvalue1(2) assms(2)
      by metis
  next
    case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
    thus ?thesis
      using consts_app_snoc[of es es' "[v1,v2]" "e"]
      apply simp
      apply (metis reduce_to_n_consts)
      done
  qed auto
qed

lemma no_reduce_to_n_unop:
  assumes "(s, vs, [($Unop t uop)]) \<Down>k{\<Gamma>} (s', vs', res)"
  shows False
  using assms no_reduce_to_n
  by metis

lemma reduce_to_n_nop:
  assumes "((s,vs,($$*ves)@[$Nop]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue (ves)"
  using assms
proof (induction "(s,vs,($$*ves)@[$Nop])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  thus ?case
    using consts_app_snoc[OF const_value(4)]
    apply simp
    apply (metis (mono_tags, lifting) b_e.distinct(95) e.inject(1) inj_basic_econst last_map last_snoc map_injective)
    done
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    by (metis is_const_list)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    by (metis seq_nonvalue1.hyps(3,4,6))
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    by (metis is_const_list seq_nonvalue2.hyps(4))
qed auto

lemma reduce_to_n_get_local:
  assumes "((s,vs,($$*ves)@[$Get_local j]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> j < length vs \<and> res = RValue (ves@[vs!j])"
  using assms
proof (induction "(s,vs,($$*ves)@[$Get_local j])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  thus ?case
    using consts_app_snoc[OF const_value(4)]
    apply safe
    apply simp_all
    apply ((metis const_value.hyps(4) consts_app_ex(2) reduce_to_n_consts)+)[2]
    apply ((metis b_e.simps(585) consts_cons_last(2) e.inject(1) e_type_const_unwrap)+)[2]
    apply blast
    apply (metis inj_basic_econst map_injective)
    done
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    by (metis is_const_list)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    by (metis seq_nonvalue1.hyps(3,4,6))
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    by (metis is_const_list seq_nonvalue2.hyps(4))
qed auto

lemma reduce_to_n_set_local:
  assumes "((s,vs,($$*ves)@[$C v, $Set_local j]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs[j:= v] = vs' \<and> j < length vs \<and> res = RValue (ves)"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v, $Set_local j])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  thus ?case
    using consts_app_snoc_1[OF const_value(4)]
    apply simp
    apply (metis (no_types, lifting) b_e.distinct(589) e.inject(1) e_type_const_unwrap no_reduce_to_n)
    done
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (meson b_e.distinct(589) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  obtain vcs' where ves'_is:"ves' = $$* vcs'"
    using seq_nonvalue1 e_type_const_conv_vs
    by blast
  show ?case
    using consts_app_snoc_1[of vcs' es ves v "$Set_local j"] seq_nonvalue1(7)  ves'_is
          local.seq_nonvalue1(2) no_reduce_to_n seq_nonvalue1.hyps(3,4)
    apply (simp add: is_const_def)
    apply metis
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma reduce_to_n_tee_local:
  assumes "((s,vs,($$*ves)@[$C v, $Tee_local j]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "((s,vs,($$*ves)@[$C v, $C v, $Set_local j]) \<Down>k{\<Gamma>} (s',vs',res))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v, $Tee_local j])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves)
  thus ?case
    using consts_app_snoc_1[OF const_value(4)]
    apply (simp add: is_const_def)
    apply safe
    apply (meson no_reduce_to_n)
    apply (meson no_reduce_to_n)
    apply (simp add: reduce_to_n.const_value)
    done
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (meson b_e.distinct(613) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  obtain vcs' where ves'_is:"ves' = $$* vcs'"
    using seq_nonvalue1 e_type_const_conv_vs
    by blast
  show ?case
    using consts_app_snoc_1[of vcs' es ves v "$Tee_local j"] seq_nonvalue1(7)  ves'_is
          local.seq_nonvalue1(2) no_reduce_to_n seq_nonvalue1.hyps(1,3,4,5)
    apply (simp add: is_const_def)
    apply safe
      apply (meson no_reduce_to_n)
    apply (meson no_reduce_to_n)
    apply (simp add: reduce_to_n.seq_nonvalue1)
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma reduce_to_n_get_global:
  assumes "((s,vs,($$*ves)@[$Get_global j]) \<Down>k{(ls,r,i)} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue (ves@[(sglob_val s i j)])"
  using assms
proof (induction "(s,vs,($$*ves)@[$Get_global j])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k s' vs' res ves ves')
  thus ?case
    using consts_app_snoc[OF const_value(4)]
    apply safe
    apply simp_all
    apply ((metis const_value.hyps(4) consts_app_ex(2) reduce_to_n_consts)+)[2]
    apply (metis b_e.simps(657) e.inject(1) last_map last_snoc)
    apply (metis inj_basic_econst map_injective)
    done
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    by (metis is_const_list)
next
  case (seq_nonvalue1 ves' s vs es k s' vs' res)
  show ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    by (metis seq_nonvalue1.hyps(3,4,6))
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    by (metis is_const_list seq_nonvalue2.hyps(4))
qed auto

lemma reduce_to_n_set_global:
  assumes "((s,vs,($$*ves)@[$C v, $Set_global j]) \<Down>k{(ls,r,i)} (s',vs',res))"
  shows "(supdate_glob s i j v) = s' \<and> vs = vs' \<and> res = RValue (ves)"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v, $Set_global j])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k s' vs' res ves ves')
  thus ?case
    using consts_app_snoc_1[OF const_value(4)]
    apply simp
    apply (metis (no_types, lifting) b_e.distinct(655) e.inject(1) e_type_const_unwrap no_reduce_to_n)
    done
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (meson b_e.distinct(655) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k s' vs' res)
  obtain vcs' where ves'_is:"ves' = $$* vcs'"
    using seq_nonvalue1 e_type_const_conv_vs
    by blast
  show ?case
    using consts_app_snoc_1[of vcs' es ves v "$Set_global j"] seq_nonvalue1(7)  ves'_is
          local.seq_nonvalue1(2) no_reduce_to_n seq_nonvalue1.hyps(3,4)
    apply (simp add: is_const_def)
    apply metis
    done
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma reduce_to_n_load:
  assumes "((s,vs,($$*ves)@[$C ConstInt32 c, $Load t None a off]) \<Down>k{(ls,r,i)} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> (\<exists>j m. smem_ind s i = Some j \<and> ((mems s)!j) = m \<and> (\<exists>bs. (load m (nat_of_int c) off (t_length t) = Some bs \<and> res = RValue (ves@[(wasm_deserialise bs t)])) \<or> (load m (nat_of_int c) off (t_length t) = None \<and> res = RTrap)))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C ConstInt32 c, $Load t None a off])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k s' vs' res ves ves')
  consider (1) "es = [$Load t None a off] \<and> ves = ves' @ [ConstInt32 c]"
         | (2) ves'' where "(es = ($$* ves'') @ [$C ConstInt32 c, $Load t None a off] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_1[OF const_value(4)]
    by (fastforce simp add: is_const_def)
  thus ?case
    using const_value
    apply (cases)
    apply simp_all
    apply (meson no_reduce_to_n)
    apply blast
    done
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (metis b_e.simps(695) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k s' vs' res)
  obtain vcs' where ves'_is:"ves' = $$* vcs'"
    using seq_nonvalue1 e_type_const_conv_vs
    by blast
  show ?case
    using consts_app_snoc_1[of vcs' es ves "ConstInt32 c" "$Load t None a off"] seq_nonvalue1(7)  ves'_is
          local.seq_nonvalue1(2) no_reduce_to_n seq_nonvalue1.hyps(3,4)
    apply (simp add: is_const_def)
    apply metis
    done
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

(*   "load_packed sx m n off lp l = map_option (sign_extend sx l) (load m n off lp)" *)
lemma reduce_to_n_load_packed:
  assumes "((s,vs,($$*ves)@[$C ConstInt32 c, $(Load t (Some (tp, sx)) a off)]) \<Down>k{(ls,r,i)} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> (\<exists>j m. smem_ind s i = Some j \<and> ((mems s)!j) = m \<and> (\<exists>bs. (load m (nat_of_int c) off (tp_length tp) = Some bs \<and> res = RValue (ves@[(wasm_deserialise (sign_extend sx (t_length t) bs) t)])) \<or> (load m (nat_of_int c) off (tp_length tp) = None \<and> res = RTrap)))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C ConstInt32 c, $(Load t (Some (tp, sx)) a off)])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k s' vs' res ves ves')
  consider (1) "es = [$(Load t (Some (tp, sx)) a off)] \<and> ves = ves' @ [ConstInt32 c]"
         | (2) ves'' where "(es = ($$* ves'') @ [$C ConstInt32 c, $(Load t (Some (tp, sx)) a off)] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_1[OF const_value(4)]
    by (fastforce simp add: is_const_def)
  thus ?case
    using const_value
    apply (cases)
    apply simp_all
    apply (meson no_reduce_to_n)
    apply blast
    done
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (metis b_e.simps(695) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k s' vs' res)
  obtain vcs' where ves'_is:"ves' = $$* vcs'"
    using seq_nonvalue1 e_type_const_conv_vs
    by blast
  show ?case
    using consts_app_snoc_1[of vcs' es ves "ConstInt32 c" "$(Load t (Some (tp, sx)) a off)"] seq_nonvalue1(7)  ves'_is
          local.seq_nonvalue1(2) no_reduce_to_n seq_nonvalue1.hyps(3,4)
    apply (simp add: is_const_def)
    apply metis
    done
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed (auto simp add: load_packed_def)
(* | store_Some:"\<lbrakk>types_agree t v; smem_ind s i = Some j; ((mems s)!j) = m; store m (nat_of_int n) off (bits v) (t_length t) = Some mem'\<rbrakk> \<Longrightarrow> (s,vs,[$C (ConstInt32 n), $C v, $(Store t None a off)]) \<Down>k{(ls,r,i)} (s\<lparr>mems:= ((mems s)[j := mem'])\<rparr>,vs,RValue [])"
*)
lemma reduce_to_n_store:
  assumes "((s,vs,($$*ves)@[$C (ConstInt32 c), $C v, $Store t None a off]) \<Down>k{(ls,r,i)} (s',vs',res))"
  shows "vs = vs' \<and> types_agree t v \<and> (\<exists>j m. smem_ind s i = Some j \<and> s.mems s ! j = m \<and>
           ((s = s' \<and> store (s.mems s ! j) (Wasm_Base_Defs.nat_of_int c) off (bits v) (t_length t) = None \<and> res = RTrap) \<or>
            (\<exists>mem'. store (s.mems s ! j) (Wasm_Base_Defs.nat_of_int c) off (bits v) (t_length t) = Some mem' \<and> s' = s\<lparr>s.mems := (s.mems s)[j := mem']\<rparr> \<and> res = RValue ves)))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C (ConstInt32 c), $C v, $Store t None a off])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k s' vs' res ves ves')
  consider (1) "(es = [$Store t None a off] \<and> ves = ves' @ [ConstInt32 c, v])"
         | (2) "(es = [$C v, $Store t None a off] \<and> ves = ves'@[ConstInt32 c])"
         | (3) "(\<exists>ves''. es = ($$*ves'')@[$C ConstInt32 c, $C v, $Store t None a off] \<and> ves' = ves@ves'')"
    using consts_app_snoc_2[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n const_value(1)
      by metis
  next
    case 2
    thus ?thesis
      using no_reduce_to_n2 const_value(1)
      by blast
  next
    case 3
    thus ?thesis
      using const_value.hyps(2)
      by auto
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_2_const_list[OF seq_value(7)]
    by (meson b_e.distinct(689) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k s' vs' res)
  show ?case
    using consts_app_snoc_2[of _ es "ves" "ConstInt32 c" "v" "$Store t None a off"]
    apply (simp add: is_const_def)
    apply (metis (no_types, lifting) e_type_const_conv_vs no_reduce_to_n no_reduce_to_n2 seq_nonvalue1.hyps(1,2,3,4) seq_nonvalue1.hyps(7))
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_2_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma reduce_to_n_store_packed:
  assumes "((s,vs,($$*ves)@[$C (ConstInt32 c), $C v, $Store t (Some tp) a off]) \<Down>k{(ls,r,i)} (s',vs',res))"
  shows "vs = vs' \<and> types_agree t v \<and> (\<exists>j m. smem_ind s i = Some j \<and> s.mems s ! j = m \<and>
           ((s = s' \<and> store (s.mems s ! j) (Wasm_Base_Defs.nat_of_int c) off (bits v) (tp_length tp) = None \<and> res = RTrap) \<or>
            (\<exists>mem'. store (s.mems s ! j) (Wasm_Base_Defs.nat_of_int c) off (bits v) (tp_length tp) = Some mem' \<and> s' = s\<lparr>s.mems := (s.mems s)[j := mem']\<rparr> \<and> res = RValue ves)))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C (ConstInt32 c), $C v, $Store t (Some tp) a off])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k s' vs' res ves ves')
  consider (1) "(es = [$Store t (Some tp) a off] \<and> ves = ves' @ [ConstInt32 c, v])"
         | (2) "(es = [$C v, $Store t (Some tp) a off] \<and> ves = ves'@[ConstInt32 c])"
         | (3) "(\<exists>ves''. es = ($$*ves'')@[$C ConstInt32 c, $C v, $Store t (Some tp) a off] \<and> ves' = ves@ves'')"
    using consts_app_snoc_2[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n const_value(1)
      by metis
  next
    case 2
    thus ?thesis
      using no_reduce_to_n2 const_value(1)
      by blast
  next
    case 3
    thus ?thesis
      using const_value.hyps(2)
      by auto
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_2_const_list[OF seq_value(7)]
    by (meson b_e.distinct(689) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k s' vs' res)
  show ?case
    using consts_app_snoc_2[of _ es "ves" "ConstInt32 c" "v" "$Store t (Some tp) a off"]
    apply (simp add: is_const_def)
    apply (metis (no_types, lifting) e_type_const_conv_vs no_reduce_to_n no_reduce_to_n2 seq_nonvalue1.hyps(1,2,3,4) seq_nonvalue1.hyps(7))
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_2_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed (auto simp add: store_packed_def)

lemma reduce_to_n_drop:
  assumes "((s,vs,($$*ves)@[$C v, $Drop]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue (ves)"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v, $Drop])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  consider (1) "es = [$Drop] \<and> ves = ves' @ [v]" | (2) "(\<exists>ves''. es = ($$* ves'') @ [$C v, $Drop] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_1[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n const_value(1)
      by metis
  next
    case 2
    then obtain ves'' where "es = ($$* ves'') @ [$C v, $Drop]"
                            "ves'  = ves @ ves''"
      by blast
    thus ?thesis
      using const_value(2)
      by auto
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (metis b_e.simps(167) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc_1[of _ es "ves" "v" "$Drop"] e_type_const_conv_vs[of ves']
          no_reduce_to_n seq_nonvalue1
    apply (simp add: is_const_def)
    apply metis
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
next
qed auto

lemma reduce_to_n_select:
  assumes "((s,vs,($$*ves)@[$C v1, $C v2, $C ConstInt32 n, $Select]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> ((res = RValue (ves@[v2]) \<and> int_eq n 0) \<or> (res = RValue (ves@[v1]) \<and> int_ne n 0))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v1, $C v2, $C ConstInt32 n, $Select])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  consider (1) "es = [$Select] \<and> ves = ves' @ [v1, v2, ConstInt32 n]"
         | (2) "es = [$C ConstInt32 n, $Select] \<and> ves = ves' @ [v1, v2]"
         | (3) "es = [$C v2, $C ConstInt32 n, $Select] \<and>  ves = ves' @ [v1]"
         | (4) ves'' where "(es = ($$* ves'') @ [$C v1, $C v2, $C ConstInt32 n, $Select] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_3[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      by (metis const_value.hyps(1) no_reduce_to_n)
  next
    case 2
    thus ?thesis
      by (metis const_value.hyps(1) no_reduce_to_n2)
  next
    case 3
    thus ?thesis
      by (metis const_value.hyps(1) no_reduce_to_n3)
  next
    case 4
    thus ?thesis
      using const_value(2)
      by (metis append.assoc res_b.inject(1))
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_3_const_list[OF seq_value(7)]
    by (metis b_e.distinct(193) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc_3[of _ es "ves" v1 v2 "ConstInt32 n" "$Select"] e_type_const_conv_vs[of ves']
          no_reduce_to_n seq_nonvalue1
    apply (simp add: is_const_def)
    apply (metis no_reduce_to_n2 no_reduce_to_n3)
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_3_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma reduce_to_n_unop:
  assumes "((s,vs,($$*ves)@[$C v, $Unop t op]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue (ves@[(app_unop op v)])"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v, $Unop t op])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  consider (1) "es = [$Unop t op] \<and> ves = ves' @ [v]" | (2) "(\<exists>ves''. es = ($$* ves'') @ [$C v, $Unop t op] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_1[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n_unop const_value(1)
      by blast
  next
    case 2
    then obtain ves'' where "es = ($$* ves'') @ [$C v, $Unop t op]"
                            "ves'  = ves @ ves''"
      by blast
    thus ?thesis
      using const_value(2)
      by auto
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (metis b_e.distinct(727) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc_1[of _ es "ves" "v" "$Unop t op"] e_type_const_conv_vs[of ves']
          no_reduce_to_n_unop seq_nonvalue1
    apply (simp add: is_const_def)
    apply blast
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
next
qed auto

lemma no_reduce_to_n_testop:
  assumes "(s, vs, [$Testop t op]) \<Down>k{\<Gamma>} (s', vs', res)"
  shows False
  using assms no_reduce_to_n
  by metis

lemma reduce_to_n_testop:
  assumes "((s,vs,($$*ves)@[$C v, $Testop t op]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue (ves@[(app_testop op v)])"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v, $Testop t op])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  consider (1) "es = [$Testop t op] \<and> ves = ves' @ [v]" | (2) "(\<exists>ves''. es = ($$* ves'') @ [$C v, $Testop t op] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_1[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n_testop const_value(1)
      by blast
  next
    case 2
    then obtain ves'' where "es = ($$* ves'') @ [$C v, $Testop t op]"
                            "ves'  = ves @ ves''"
      by blast
    thus ?thesis
      using const_value(2)
      by auto
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (metis b_e.distinct(731) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc_1[of _ es "ves" "v" "$Testop t op"] e_type_const_conv_vs[of ves']
          no_reduce_to_n_testop seq_nonvalue1
    apply (simp add: is_const_def)
    apply blast
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
next
qed auto

lemma no_reduce_to_n_binop:
  assumes "(s, vs, [$Binop t op]) \<Down>k{\<Gamma>} (s', vs', res)"
  shows False
  using assms no_reduce_to_n
  by metis

lemma no_reduce_to_n2_binop:
  assumes "(s, vs, [$C v, $Binop t op]) \<Down>k{\<Gamma>} (s', vs', res)"
  shows False
  using assms no_reduce_to_n2
  by blast

lemma reduce_to_n_binop:
  assumes "((s,vs,($$*ves)@[$C v1, $C v2, $Binop t op]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and>
         ((\<exists>v. (app_binop op v1 v2 = Some v) \<and> res = RValue (ves@[v])) \<or>
            (\<exists>v. (app_binop op v1 v2 = None) \<and> res = RTrap))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v1, $C v2, $Binop t op])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  consider (1) "(es = [$Binop t op] \<and> ves = ves' @ [v1, v2])"
         | (2) "(es = [$C v2, $Binop t op] \<and> ves = ves'@[v1])"
         | (3) "(\<exists>ves''. es = ($$*ves'')@[$C v1, $C v2, $Binop t op] \<and> ves' = ves@ves'')"
    using consts_app_snoc_2[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n_binop const_value(1)
      by blast
  next
    case 2
    thus ?thesis
      using no_reduce_to_n2_binop const_value(1)
      by blast
  next
    case 3
    thus ?thesis
      using const_value.hyps(2)
      by auto
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_2_const_list[OF seq_value(7)]
    by (metis b_e.distinct(729) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc_2[of _ es "ves" "v1" "v2" "$Binop t op"]
    apply (simp add: is_const_def)
    apply (metis (no_types, lifting) e_type_const_conv_vs no_reduce_to_n2_binop no_reduce_to_n_binop seq_nonvalue1.hyps(1) seq_nonvalue1.hyps(2,3,4) seq_nonvalue1.hyps(7))
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_2_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma no_reduce_to_n_relop:
  assumes "(s, vs, [$Relop t op]) \<Down>k{\<Gamma>} (s', vs', res)"
  shows False
  using assms no_reduce_to_n
  by metis

lemma no_reduce_to_n2_relop:
  assumes "(s, vs, [$C v, $Relop t op]) \<Down>k{\<Gamma>} (s', vs', res)"
  shows False
  using assms no_reduce_to_n2
  by blast

lemma reduce_to_n_relop:
  assumes "((s,vs,($$*ves)@[$C v1, $C v2, $Relop t op]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue (ves@[(app_relop op v1 v2)])"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v1, $C v2, $Relop t op])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  consider (1) "(es = [$Relop t op] \<and> ves = ves' @ [v1, v2])"
         | (2) "(es = [$C v2, $Relop t op] \<and> ves = ves'@[v1])"
         | (3) "(\<exists>ves''. es = ($$*ves'')@[$C v1, $C v2, $Relop t op] \<and> ves' = ves@ves'')"
    using consts_app_snoc_2[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n_relop const_value(1)
      by blast
  next
    case 2
    thus ?thesis
      using no_reduce_to_n2_relop const_value(1)
      by blast
  next
    case 3
    thus ?thesis
      by (metis append.assoc const_value.hyps(2) res_b.inject(1))
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_2_const_list[OF seq_value(7)]
    by (metis b_e.distinct(733) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc_2[of _ es "ves" "v1" "v2" "$Relop t op"]
    by (metis (no_types, lifting) b_e.distinct(733) e.inject(1) e_type_const_conv_vs e_type_const_unwrap no_reduce_to_n_relop no_reduce_to_n2_relop seq_nonvalue1.hyps(1,2,3,4) seq_nonvalue1.hyps(7))
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_2_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma reduce_to_n_convert:
  assumes "((s,vs,($$*ves)@[$C v, $Cvtop t2 Convert t1 sx]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> types_agree t1 v \<and>
         (\<exists>v'. (res = RValue (ves@[v']) \<and> cvt t2 sx v = (Some v')) \<or> 
          (res = RTrap \<and> cvt t2 sx v = None))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v, $Cvtop t2 Convert t1 sx])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  consider (1) "es = [$Cvtop t2 Convert t1 sx] \<and> ves = ves' @ [v]" | (2) "(\<exists>ves''. es = ($$* ves'') @ [$C v, $Cvtop t2 Convert t1 sx] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_1[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n const_value(1)
      by metis
  next
    case 2
    then obtain ves'' where "es = ($$* ves'') @ [$C v, $Cvtop t2 Convert t1 sx]"
                            "ves'  = ves @ ves''"
      by blast
    thus ?thesis
      using const_value(2)
      by fastforce
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (metis b_e.distinct(735) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc_1[of _ es "ves" "v" "$Cvtop t2 Convert t1 sx"] e_type_const_conv_vs[of ves']
          no_reduce_to_n seq_nonvalue1
    apply (simp add: is_const_def)
    apply metis
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma reduce_to_n_reinterpret:
  assumes "((s,vs,($$*ves)@[$C v, $Cvtop t2 Reinterpret t1 None]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "s = s' \<and> vs = vs' \<and> res = RValue (ves@[(wasm_deserialise (bits v) t2)]) \<and> types_agree t1 v"
  using assms
proof (induction "(s,vs,($$*ves)@[$C v, $Cvtop t2 Reinterpret t1 None])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs vs' s' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  consider (1) "es = [$Cvtop t2 Reinterpret t1 None] \<and> ves = ves' @ [v]" | (2) "(\<exists>ves''. es = ($$* ves'') @ [$C v, $Cvtop t2 Reinterpret t1 None] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_1[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n const_value(1)
      by metis
  next
    case 2
    then obtain ves'' where "es = ($$* ves'') @ [$C v, $Cvtop t2 Reinterpret t1 None]"
                            "ves'  = ves @ ves''"
      by blast
    thus ?thesis
      using const_value(2)
      by auto
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (metis b_e.distinct(735) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves' s vs es k \<Gamma> s' vs' res)
  show ?case
    using consts_app_snoc_1[of _ es "ves" "v" "$Cvtop t2 Reinterpret t1 None"] e_type_const_conv_vs[of ves']
          no_reduce_to_n seq_nonvalue1
    apply (simp add: is_const_def)
    apply metis
    done
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma no_reduce_to_n_grow_memory:
  assumes "(s, vs, [$Grow_memory]) \<Down>k{(ls, r, i)} (s', vs', res)"
  shows False
  using assms
  apply (induction "(s,vs,[$Grow_memory])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res k rule: reduce_to_n.induct)
  apply simp_all
  apply (metis append_eq_Cons_conv b_e.distinct(715) consts_cons(2) e.inject(1) e_type_const_unwrap)
  apply (metis Cons_eq_append_conv append.right_neutral append_is_Nil_conv consts_app_ex(2) is_const_list)
  apply (simp add: append_eq_Cons_conv)
  apply (metis Nil_is_append_conv append_eq_Cons_conv reduce_to_n_emp)
  done

lemma reduce_to_n_grow_memory:
  assumes "((s,vs,($$*ves)@[$C ConstInt32 c, $Grow_memory]) \<Down>k{(ls,r,i)} (s',vs',res))"
  shows "\<exists>n j m. (vs = vs' \<and> smem_ind s i = Some j \<and> ((mems s)!j) = m \<and> mem_size m = n) \<and> ((s = s' \<and> res = RValue (ves@[ConstInt32 int32_minus_one])) \<or> (\<exists>mem'. (mem_grow (s.mems s ! j) (Wasm_Base_Defs.nat_of_int c)) = Some mem' \<and> s' = s \<lparr>s.mems := (s.mems s)[j := mem']\<rparr> \<and> res = RValue (ves@[ConstInt32 (int_of_nat n)])))"
  using assms
proof (induction "(s,vs,($$*ves)@[$C ConstInt32 c, $Grow_memory])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs vs' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es k vs' res ves ves')
  consider (1) "es = [$Grow_memory] \<and> ves = ves' @ [ConstInt32 c]" | (2) "(\<exists>ves''. es = ($$* ves'') @ [$C ConstInt32 c, $Grow_memory] \<and> ves' = ves @ ves'')"
    using consts_app_snoc_1[OF const_value(4)] is_const_def
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n_grow_memory const_value(1)
      by blast
  next
    case 2
    then obtain ves'' where "es = ($$* ves'') @ [$C ConstInt32 c, $Grow_memory]"
                            "ves'  = ves @ ves''"
      by blast
    thus ?thesis
      using const_value(2)
      by auto
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (meson b_e.distinct(715) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves s vs es k vs' res ves')
  show ?case
    using consts_app_snoc_1[of _ es "ves'" "ConstInt32 c" "$Grow_memory"] e_type_const_conv_vs[of ves]
          no_reduce_to_n_grow_memory seq_nonvalue1
    apply (simp add: is_const_def)
    apply blast
    done
next
  case (seq_nonvalue2 s vs es k vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma calln_imp: "((s,vs,($$*ves)@[$(Call j)]) \<Down>(Suc k){(ls,r,i)} (s',vs',res)) \<Longrightarrow> ((s,vs,($$*ves)@[(Invoke (sfunc s i j))]) \<Down>k{(ls,r,i)} (s',vs',res))"
proof (induction "(s,vs,($$*ves)@[$(Call j)])" "(Suc k)" "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res ves k rule: reduce_to_n.induct)
  case (const_value s vs es s' vs' res ves ves')
  consider (1) "($$* ves) = ($$* ves') @ [$Call j] \<and> es = []"
         | (2) "(\<exists>ves'a ves''.
                  ($$* ves) = ($$* ves'a) \<and>
                  es = ($$* ves'') @ [$Call j] \<and>
                  ves' = ves'a @ ves'')"
    using consts_app_snoc[OF const_value(4)]
    by fastforce
  thus ?case
  proof (cases)
    case 1
    thus ?thesis
      by (metis b_e.distinct(505) consts_cons_last(2) e.inject(1) e_type_const_unwrap)
  next
    case 2
    then obtain ves'a ves'' where ves''_def:"($$* ves) = ($$* ves'a)"
                                            "es = ($$* ves'') @ [$Call j]"
                                            "ves' = ves'a @ ves''"
      by blast
    thus ?thesis
      using const_value(2)[OF ves''_def(2)]  const_value.hyps(3) reduce_to_n.const_value
      by fastforce
  qed
next
  case (seq_value s vs es s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)] reduce_to_consts reduce_to_n_imp_reduce_to
    apply (cases "es = ($$* ves) @ [$Call j] \<and> es' = []")
    apply fastforce
    apply blast
    done
next
  case (seq_nonvalue1 ves s vs es s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    apply (auto simp add: reduce_to_n.seq_nonvalue1)
    done
next
  case (seq_nonvalue2 s vs es s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)] reduce_to_n_consts
    apply fastforce
    done
qed (fastforce intro: reduce_to_n.intros)+

lemma reduce_to_n_br_imp_length:
  assumes "(s,vs,($$* vcs) @ [$Br j]) \<Down>k{(ls,r,i)} (s',vs',res)"
  shows "length vcs \<ge> (ls!j) \<and> (\<exists>vcs'. res = RBreak j vcs')"
  using assms
proof (induction "(s,vs,($$* vcs) @ [$Br j])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (br vcs' n j' s vs k)
  hence "j = j'" "vcs = vcs'"
    using inj_basic_econst
    by auto
  thus ?case
    using br
    by simp
next
  case (const_value s vs es k s' vs' res ves)
  have "(\<exists>ves' ves''. ($$* ves) = ($$* ves') \<and> es = ($$* ves'') @ [$Br j] \<and> vcs = ves' @ ves'')"
    using const_value consts_app_snoc[OF const_value(4)]
    by (metis b_e.simps(387) consts_cons_last(2) e.inject(1) e_type_const_unwrap)
  thus ?case
    using const_value(2)
    by (metis res_b.distinct(1))
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    by (metis consts_app_snoc is_const_list)
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  thus ?case
    by (metis consts_app_snoc length_append trans_le_add2)
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    by (metis (no_types, lifting) consts_app_snoc reduce_to_consts reduce_to_n_imp_reduce_to)
qed auto

lemma reduce_to_n_br:
  assumes "(s,vs,($$* vcsf) @ ($$* vcs) @ [$Br j]) \<Down>k{(ls,r,i)} (s',vs',res)"
          "length vcs = (ls!j)"
          "j < length ls"
  shows "((s,vs,($$* vcs) @ [$Br j]) \<Down>k{(ls,r,i)} (s',vs',res)) \<and> s = s' \<and> vs = vs' \<and> (res = RBreak j vcs)"
  using assms
proof (induction "(s,vs,($$* vcsf) @ ($$* vcs) @ [$Br j])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs vcsf rule: reduce_to_n.induct)
  case (br vcs' n j' s vs k)
  hence "vcs = vcs' \<and> j = j'"
    using inj_basic_econst
    apply simp
    apply (metis append_eq_append_conv append_eq_append_conv2 length_map map_injective)
    done
  thus ?case
    by (metis br(1,2,3) reduce_to_n.br)
next
  case (const_value s vs es k s' vs' res ves)
  then consider
      (1) "($$* ves) = ($$* vcsf @ vcs) @ [$Br j] \<and> es = []"
    | (2) ves' ves'' where "ves = ves' \<and> es = ($$* ves'') @ [$Br j] \<and> vcsf @ vcs = ves' @ ves''"
    using consts_app_snoc[of "($$* ves)" es "vcsf@vcs" "$Br j"] inj_basic_econst
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      by (metis b_e.distinct(365) consts_cons_last(2) e.inject(1) e_type_const_unwrap)
  next
    case 2
    show ?thesis
    proof (cases "length ves'' \<ge> ls ! j")
      case True
      then obtain ves''_1  where "ves'' = ves''_1@vcs"
        using const_value(5) 2
        using local.const_value(1) reduce_to_n_br_imp_length by blast
      hence 3:"es = ($$* ves''_1) @ ($$* vcs) @ [$Br j]"
        using 2
        by simp
      show ?thesis
        using const_value(2)[OF 3] const_value(5,6)
        by simp
    next
      case False
      thus ?thesis
        using const_value
        by (metis 2 reduce_to_n_br_imp_length)
    qed
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[of es es' "vcsf@vcs" "$Br j"]
    apply simp
    apply (metis is_const_list)
    done
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  then obtain ves' ves'' where ves'_def:"ves = ($$* ves') \<and> es = ($$* ves'') @ [$Br j] \<and> vcsf @ vcs = ves' @ ves''"
    using consts_app_snoc[of ves es "vcsf@vcs" "$Br j"]
    by fastforce
  show ?case
  proof (cases "length ves'' \<ge> ls ! j")
    case True
    then obtain ves''_1  where "ves'' = ves''_1@vcs"
      using seq_nonvalue1(8)
      by (metis (no_types, hide_lams) add.commute append_eq_append_conv_if length_append nat_add_left_cancel_le ves'_def)
    thus ?thesis
      using ves'_def seq_nonvalue1
      by (metis append_assoc map_append)
  next
    case False
    thus ?thesis
      using ves'_def seq_nonvalue1
      by (metis reduce_to_n_br_imp_length)
  qed

next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[of es es' "vcsf@vcs" "$Br j"]
    apply simp
    apply (metis reduce_to_n_consts)
    done
qed auto


lemma reduce_to_n_br_n:
  assumes "(s,vs,($$* vcs) @ [$Br j]) \<Down>k{(ls,r,i)} (s',vs',res)"
          "ls!j = n"
          "length vcs = n"
  shows "res = RBreak j vcs"
  using assms
proof (induction "(s,vs,($$* vcs) @ [$Br j])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (br vcs n j s vs k)
  thus ?case
    using inj_basic_econst
    by auto
next
  case (const_value s vs es k s' vs' res ves)
  thus ?case
    using consts_app_snoc[OF const_value(4)]
    apply simp
    apply safe
    apply (metis b_e.simps(387) consts_cons_last(2) e.inject(1) e_type_const_unwrap)
    apply (metis le_add2 le_antisym length_append reduce_to_n_br_imp_length)
    done
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    apply simp
    apply (metis is_const_list)
    done
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    apply safe
    apply simp_all
    apply (metis add_le_same_cancel2 le_zero_eq length_0_conv reduce_to_n_br_imp_length)
    apply (metis add_le_same_cancel2 le_zero_eq length_0_conv reduce_to_n_br_imp_length)
    done
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    apply safe
    apply simp_all
    apply (metis reduce_to_n_consts)
    apply (metis reduce_to_n_consts)
    done
qed auto

lemma reduce_to_n_return_imp_length:
  assumes "(s,vs,($$* vcs) @ [$Return]) \<Down>k{(ls,r,i)} (s',vs',res)"
  shows "\<exists>r'. r = Some r' \<and> (length vcs \<ge> r') \<and> (\<exists>vcs'. res = RReturn vcs')"
  using assms
proof (induction "(s,vs,($$* vcs) @ [$Return])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (return vcs' r' s vs k)
  hence "vcs = vcs' \<and> length vcs = r'"
    using inj_basic_econst
    by auto
  thus ?case
    using return
    by (metis eq_iff)
next
  case (const_value s vs es k s' vs' res ves)
  have "(\<exists>ves' ves''. ($$* ves) = ($$* ves') \<and> es = ($$* ves'') @ [$Br j] \<and> vcs = ves' @ ves'')"
    using const_value consts_app_snoc[OF const_value(4)]
    by (metis b_e.distinct(473) const_list_cons_last(2) e.inject(1) e_type_const_unwrap is_const_list res_b.distinct(3))
  thus ?case
    using const_value(2)
    by (metis append_is_Nil_conv b_e.distinct(341) const_value.hyps(4) e.inject(1) last_appendR last_snoc)
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    by (metis consts_app_snoc is_const_list)
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  thus ?case
    by (metis consts_app_snoc length_append trans_le_add2)
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    by (metis (no_types, lifting) consts_app_snoc reduce_to_consts reduce_to_n_imp_reduce_to)
qed auto

lemma reduce_to_n_return:
  assumes "(s,vs,($$* vcsf) @ ($$* vcs) @ [$Return]) \<Down>k{(ls,r,i)} (s',vs',res)"
          "r = Some (length vcs)"
  shows "((s,vs,($$* vcs) @ [$Return]) \<Down>k{(ls,r,i)} (s',vs',res)) \<and> s = s' \<and> vs = vs' \<and> (res = RReturn vcs)"
  using assms
proof (induction "(s,vs,($$* vcsf) @ ($$* vcs) @ [$Return])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs vcsf rule: reduce_to_n.induct)
  case (return vcs' r' s vs k)
  hence "vcs = vcs' \<and> length vcs = r'"
    using inj_basic_econst
    apply simp
    apply (metis append_eq_append_conv append_eq_append_conv2 map_append map_injective)
    done
  thus ?case
    by (metis reduce_to_n.return return.hyps(3))
next
  case (const_value s vs es k s' vs' res ves)
  then consider
      (1) "($$* ves) = ($$* vcsf @ vcs) @ [$Return] \<and> es = []"
    | (2) ves' ves'' where "ves = ves' \<and> es = ($$* ves'') @ [$Return] \<and> vcsf @ vcs = ves' @ ves''"
    using consts_app_snoc[of "($$* ves)" es "vcsf@vcs" "$Return"] inj_basic_econst
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      by (metis b_e.distinct(473) consts_cons_last(2) e.inject(1) e_type_const_unwrap)
  next
    case 2
    show ?thesis
    proof (cases "length ves'' \<ge> the r")
      case True
      then obtain ves''_1  where "ves'' = ves''_1@vcs"
        using const_value(5) 2
        using local.const_value(1) reduce_to_n_return_imp_length by blast
      hence 3:"es = ($$* ves''_1) @ ($$* vcs) @ [$Return]"
        using 2
        by simp
      show ?thesis
        using const_value(2)[OF 3] const_value(5)
        by simp
    next
      case False
      thus ?thesis
        using const_value
        by (metis "2" reduce_to_n_return_imp_length res_b.distinct(3))
    qed
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[of es es' "vcsf@vcs" "$Return"]
    apply simp
    apply (metis is_const_list)
    done
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  then obtain ves' ves'' where ves'_def:"ves = ($$* ves') \<and> es = ($$* ves'') @ [$Return] \<and> vcsf @ vcs = ves' @ ves''"
    using consts_app_snoc[of ves es "vcsf@vcs" "$Return"]
    by fastforce
  show ?case
  proof (cases "length ves'' \<ge> the r")
    case True
    then obtain ves''_1  where "ves'' = ves''_1@vcs"
      using seq_nonvalue1(8)
      apply simp
      by (metis add.commute append_eq_append_conv_if length_append nat_add_left_cancel_le ves'_def)
    thus ?thesis
      using ves'_def seq_nonvalue1
      by (metis append_assoc map_append)
  next
    case False
    hence "length vcs > length ves''"
      by (simp add: seq_nonvalue1.prems)
    thus ?thesis
      using reduce_to_n_return_imp_length not_less seq_nonvalue1.hyps(2) seq_nonvalue1.prems ves'_def
      by blast
  qed
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[of es es' "vcsf@vcs" "$Return"]
    apply simp
    apply (metis reduce_to_n_consts)
    done
qed auto

lemma reduce_to_n_return_n:
  assumes "(s,vs,($$* vcs) @ [$Return]) \<Down>k{(ls,r,i)} (s',vs',res)"
          "r = Some n"
          "length vcs = n"
  shows "res = RReturn vcs"
  using assms
proof (induction "(s,vs,($$* vcs) @ [$Return])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (return vcs r s vs k)
  thus ?case
    using inj_basic_econst
    by auto
next
  case (const_value s vs es k s' vs' res ves)
  thus ?case
    using consts_app_snoc[OF const_value(4)]
    apply simp
    apply safe
    apply (metis b_e.distinct(473) consts_cons_last(2) e.inject(1) e_type_const_unwrap)
    apply (metis reduce_to_n_return_imp_length res_b.simps(7))
    done
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    apply simp
    apply (metis is_const_list)
    done
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    apply safe
    apply simp_all
    apply (metis add_le_same_cancel2 le_zero_eq length_0_conv option.sel reduce_to_n_return_imp_length)
    apply (metis add_le_same_cancel2 le_zero_eq length_0_conv option.sel reduce_to_n_return_imp_length)
    done
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    apply safe
    apply simp_all
    apply (metis reduce_to_n_consts)
    apply (metis reduce_to_n_consts)
    done
qed auto

lemma calln: "((s,vs,($$*ves)@[$(Call j)]) \<Down>(Suc k){(ls,r,i)} (s',vs',res)) = ((s,vs,($$*ves)@[(Invoke (sfunc s i j))]) \<Down>k{(ls,r,i)} (s',vs',res))"
  using calln_imp reduce_to_n.call
  by (metis is_const_list)

lemma reduce_to_n_block_imp_length:
  assumes "(s,vs,($$*vcs) @ [$(Block (t1s _> t2s) es)]) \<Down>k{\<Gamma>} (s',vs',res)"
  shows "length ($$*vcs) \<ge> length t1s"
  using assms
proof (induction "(s,vs,($$*vcs) @ [$(Block (t1s _> t2s) es)])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves)
  thus ?case
    using consts_app_snoc[OF const_value(4)] consts_cons_last[of _ _ ves] is_const_def
    by fastforce
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    by (metis is_const_list)
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    by force
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    by (metis reduce_to_n_consts)
qed auto

lemma reduce_to_n_loop_imp_length:
  assumes "(s,vs,($$*vcs) @ [$(Loop (t1s _> t2s) es)]) \<Down>k{\<Gamma>} (s',vs',res)"
  shows "length ($$*vcs) \<ge> length t1s"
  using assms
proof (induction "(s,vs,($$*vcs) @ [$(Loop (t1s _> t2s) es)])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves)
  thus ?case
    using consts_app_snoc[OF const_value(4)] consts_cons_last[of _ _ ves] is_const_def
    by fastforce
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    by (metis is_const_list)
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    by force
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    by (metis reduce_to_n_consts)
qed auto

lemma reduce_to_n_if:
  assumes "(s,vs,($$*vcs) @ [$C ConstInt32 c, $(If tf es1 es2)]) \<Down>k{\<Gamma>} (s',vs',res)"
  shows "(((s,vs,($$*vcs) @ [$(Block tf es1)]) \<Down>k{\<Gamma>} (s',vs',res)) \<and> int_ne c 0) \<or>
         (((s,vs,($$*vcs) @ [$(Block tf es2)]) \<Down>k{\<Gamma>} (s',vs',res)) \<and> int_eq c 0)"
  using assms
proof (induction "(s,vs,($$*vcs) @ [$C ConstInt32 c, $(If tf es1 es2)])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves)
  thus ?case
    using consts_app_snoc_1[OF const_value(4)]
    apply (simp add: is_const_def)
    apply safe
    apply simp_all
    apply ((metis no_reduce_to_n)+)[6]
    apply ((metis reduce_to_n.const_value)+)[3]
    done
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_value(7)]
    by (metis b_e.distinct(326) e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  obtain vesc where ves_is:"ves = $$* vesc"
    using e_type_const_conv_vs[OF seq_nonvalue1(1)]
    by blast
  then consider (1) "es = [$If tf es1 es2]" "vesc = vcs @ [ConstInt32 c]"
              | (2) ves'' where "es = ($$* ves'') @ [$C ConstInt32 c, $If tf es1 es2]"
                                "vcs = vesc @ ves''"
    using consts_app_snoc_1[of vesc es vcs "ConstInt32 c" "$(If tf es1 es2)"]
          seq_nonvalue1(7)
    by (fastforce simp add: is_const_def)
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using no_reduce_to_n seq_nonvalue1(2)
      apply simp
      apply metis
      done
  next
    case 2
    thus ?thesis
      using seq_nonvalue1(3)[OF 2(1)]
      apply simp
      apply (metis ves_is append_is_Nil_conv not_Cons_self2 reduce_to_n.seq_nonvalue1 seq_nonvalue1.hyps(1,4,5))
      done
  qed
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)]
    apply (simp add: is_const_def)
    apply (metis e_type_const_conv_vs reduce_to_n_consts)
    done
qed auto

lemma reduce_to_n_block:
  assumes "(s,vs,($$*vcsf) @ ($$*vcs) @ [$(Block (t1s _> t2s) es)]) \<Down>k{\<Gamma>} (s',vs',res)"
          "length ($$*vcs) = n"
          "length t1s = n"
          "length t2s = m"
  shows "(s,vs,($$*vcsf) @ [Label m [] (($$*vcs) @ ($* es))]) \<Down>k{\<Gamma>} (s',vs',res)"
  using assms
proof (induction "(s,vs,($$*vcsf) @ ($$*vcs) @ [$(Block (t1s _> t2s) es)])" k "\<Gamma>" "(s',vs',res)" arbitrary: s vs s' vs' res vcs vcsf rule: reduce_to_n.induct)
  case (const_value s vs es' k \<Gamma> s' vs' res ves)
  consider (1) ves_p1 ves_p2 where "es' = ($$* ves_p2) @ [$Block (t1s _> t2s) es]" "vcs = ves_p1 @ ves_p2" "ves = vcsf @ ves_p1"
         | (2) ves_p1' ves_p2' where "es' = ($$* ves_p2') @ ($$* vcs) @ [$Block (t1s _> t2s) es]" "vcsf = ves_p1' @ ves_p2'" "ves = ves_p1'"
    using consts_app_app_consts1[OF const_value(4)]
    by (fastforce simp add: is_const_def)
  thus ?case
  proof cases
    case 1
    show ?thesis
    proof (cases "length ves_p2 \<ge> n")
      case True
      hence "ves_p2 = vcs"
        using 1 const_value(5)
        by auto
      thus ?thesis
        using const_value 1
        apply simp
        apply (metis append_Nil list.simps(8) reduce_to_n.const_value)
        done
    next
      case False
      thus ?thesis
        using const_value reduce_to_n_block_imp_length
        by simp (metis 1(1))
    qed
  next
    case 2
    thus ?thesis
      using const_value(2)[OF 2(1)] const_value
      apply simp
      apply (metis reduce_to_n.const_value)
      done
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_app_consts[OF seq_value(7)]
    apply simp
    apply safe
    apply (metis (mono_tags, lifting) append_self_conv b_e.distinct(239) e.inject(1) e_type_const_unwrap is_const_list map_append)
    done
next
  case (seq_nonvalue1 ves s vs es' k \<Gamma> s' vs' res)
  consider (1) ves_p1 ves_p2 where "es' = ($$* ves_p2) @ [$Block (t1s _> t2s) es]"
                                   "vcs = ves_p1 @ ves_p2"
                                   "ves = ($$* vcsf) @ ($$* ves_p1)"
          | (2) ves_p1' ves_p2' where "es' = ($$* ves_p2') @ ($$* vcs) @ [$Block (t1s _> t2s) es]"
                                       "vcsf = ves_p1' @ ves_p2' \<and> ves = $$* ves_p1'"
    using consts_app_app_consts[OF seq_nonvalue1(7)] seq_nonvalue1
    by (fastforce simp add: is_const_def)
  thus ?case
  proof cases
    case 1
    thus ?thesis
    proof (cases "length ves_p2 \<ge> n")
      case True
      hence "ves_p2 = vcs"
        using 1 seq_nonvalue1
        by auto
      thus ?thesis
        using seq_nonvalue1 1
        apply simp
        apply (metis Nil_is_map_conv not_Cons_self2 reduce_to_n.seq_nonvalue1 self_append_conv2)
        done
    next
      case False
      thus ?thesis
        using seq_nonvalue1 reduce_to_n_block_imp_length
        by simp (metis 1(1))
    qed
  next
    case 2
    thus ?thesis
      using seq_nonvalue1(3)[OF 2(1)] reduce_to_n.seq_nonvalue1 seq_nonvalue1.hyps(1,4,5) seq_nonvalue1.prems(1,2,3)
      by auto
  qed
next
  case (seq_nonvalue2 s vs es'' k \<Gamma> s' vs' res es')
  show ?case
    using consts_app_snoc[of es'' es' "vcsf@vcs" "$Block (t1s _> t2s) es"] seq_nonvalue2(1,3,4,5)
    apply simp
    apply safe
    apply simp_all
    apply (metis reduce_to_n_consts)
    apply (metis reduce_to_n_consts)
    done
qed auto

lemma reduce_to_n_label:
  assumes "(s,vs,($$*vcs)@[Label m les es]) \<Down>k{(ls,r,i)} (s',vs',res)"
  shows "(((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RTrap)) \<and> res = RTrap) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RReturn rvs)) \<and> res = RReturn rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RValue rvs)) \<and> res = RValue (vcs@rvs)) \<or>
         (\<exists>n rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RBreak (Suc n) rvs)) \<and> res = RBreak n rvs) \<or>
         (\<exists>rvs s'' vs'' res' vcs1 vcs2. vcs = vcs1@vcs2 \<and> ((s,vs,es) \<Down>k{(m#ls,r,i)} (s'',vs'',RBreak 0 rvs)) \<and>
                         ((s'',vs'',($$*vcs2)@($$*rvs)@les) \<Down>k{(ls,r,i)} (s',vs',res')) \<and>
                         ((\<exists>rvs'. res' = RValue rvs' \<and> res = RValue (vcs1@rvs')) \<or> ((\<nexists>rvs'. res' = RValue rvs') \<and> res = res')))"
  using assms
proof (induction "(s,vs,($$*vcs)@[Label m les es])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (label_break_nil s vs es k n s'' vs'' bvs vcs les s' vs' res)
  thus ?case
    apply simp
    apply (metis append_Nil)
    done
next
  case (const_value s vs es' k s' vs' res ves)
  consider (1) "($$* ves) = ($$* vcs) @ [Label m les es]" "es' = []"
         | (2) ves' ves'' where "($$* ves) = ($$* ves')" "es' = ($$* ves'') @ [Label m les es]" "vcs = ves' @ ves''"
    using consts_app_snoc[OF const_value(4)] inj_basic_econst
    by auto
  thus ?case
  proof cases
    case 1
    thus ?thesis
      apply simp
      apply (metis const_list_cons_last(2) e.distinct(5) e_type_const_unwrap is_const_list)
      done
  next
    case 2
    thus ?thesis
      apply simp
      using const_value.hyps(2) inj_basic_econst
      by fastforce
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)] is_const_list
    by auto
next
  case (seq_nonvalue1 ves s vs es' k s' vs' res)
  obtain ves' ves'' where ves'_def:"ves = $$* ves'"
                                   "es' = ($$* ves'') @ [Label m les es]"
                                   "vcs = ves' @ ves''"
    using consts_app_snoc[OF seq_nonvalue1(7)] seq_nonvalue1(6)
    by blast
  consider (1) "((s, vs, es) \<Down>k{(m # ls, r, i)} (s', vs', res))"
               "res = RTrap \<or> (\<exists>rvs. res = RReturn rvs) \<or> (\<exists>rvs. res = RValue rvs)"
         | (2) bn brvs where "((s, vs, es) \<Down>k{(m # ls, r, i)} (s', vs', RBreak (Suc bn) brvs))"
                             "res = RBreak bn brvs"
         | (3) rvs s'' vs'' res' ves1 ves2 where
                                 "ves'' = ves1@ves2"
                                 "((s, vs, es) \<Down>k{(m # ls, r, i)} (s'', vs'', RBreak 0 rvs))"
                                 "((s'', vs'',($$*ves2)@($$* rvs) @ les) \<Down>k{(ls, r, i)} (s', vs', res'))"
                                 "(\<nexists>rvs'. res' = RValue rvs' \<and> res = res')"
    using seq_nonvalue1(3)[OF ves'_def(2)] seq_nonvalue1(4)
    by auto
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using seq_nonvalue1.hyps(4)
      by auto
  next
    case 2
    thus ?thesis
      using seq_nonvalue1.hyps(4)
      by auto
  next
    case 3
    thus ?thesis
      using ves'_def seq_nonvalue1(3)[OF ves'_def(2)] seq_nonvalue1(4)
      by auto
  qed
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)] reduce_to_n_consts
    apply simp
    apply metis
    done
qed auto

lemma reduce_to_label:
  assumes "(s,vs,($$*vcs)@[Label m les es]) \<Down>{(ls,r,i)} (s',vs',res)"
  shows "(((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RTrap)) \<and> res = RTrap) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RReturn rvs)) \<and> res = RReturn rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RValue rvs)) \<and> res = RValue (vcs@rvs)) \<or>
         (\<exists>n rvs. ((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RBreak (Suc n) rvs)) \<and> res = RBreak n rvs) \<or>
         (\<exists>rvs s'' vs'' res' vcs1 vcs2. vcs = vcs1@vcs2 \<and> ((s,vs,es) \<Down>{(m#ls,r,i)} (s'',vs'',RBreak 0 rvs)) \<and>
                         ((s'',vs'',($$*vcs2)@($$*rvs)@les) \<Down>{(ls,r,i)} (s',vs',res')) \<and>
                         ((\<exists>rvs'. res' = RValue rvs' \<and> res = RValue (vcs1@rvs')) \<or> ((\<nexists>rvs'. res' = RValue rvs') \<and> res = res')))"
proof -
  obtain k where k_is:"(s,vs,($$*vcs)@[Label m les es]) \<Down>k{(ls,r,i)} (s',vs',res)"
    using reduce_to_imp_reduce_to_n[OF assms]
    by blast
  show ?thesis
    using reduce_to_n_label[OF k_is] reduce_to_iff_reduce_to_n
    by simp blast
qed

lemma reduce_to_n_label_old:
  assumes "(s,vs,($$*vcs)@[Label m les es]) \<Down>k{(ls,r,i)} (s',vs',res)"
  shows "(((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RTrap)) \<and> res = RTrap) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RReturn rvs)) \<and> res = RReturn rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RValue rvs)) \<and> res = RValue (vcs@rvs)) \<or>
         (\<exists>n rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RBreak (Suc n) rvs)) \<and> res = RBreak n rvs) \<or>
         (\<exists>rvs s'' vs'' res'. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s'',vs'',RBreak 0 rvs)) \<and>
                         ((s'',vs'',($$*vcs)@($$*rvs)@les) \<Down>k{(ls,r,i)} (s',vs',res)))"
  using reduce_to_n_label[OF assms]
  apply safe
  apply simp_all
  apply (metis (no_types, lifting) append_self_conv2 map_append reduce_to_n.const_value)
  apply (metis (no_types, lifting) append_self_conv2 map_append reduce_to_n.const_value)
  apply (metis is_const_list reduce_to_n.seq_nonvalue1 reduce_to_n_emp self_append_conv2)
  apply (metis is_const_list reduce_to_n.seq_nonvalue1 reduce_to_n_emp self_append_conv2)
  done

lemma reduce_to_n_label_emp:
  assumes "(s,vs,($$*vcs)@[Label m [] es]) \<Down>k{(ls,r,i)} (s',vs',res)"
  shows "(((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RTrap)) \<and> res = RTrap) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RReturn rvs)) \<and> res = RReturn rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RValue rvs)) \<and> res = RValue (vcs@rvs)) \<or>
         (\<exists>n rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RBreak (Suc n) rvs)) \<and> res = RBreak n rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',RBreak 0 rvs)) \<and> res = RValue (vcs@rvs))"
  using reduce_to_n_label_old[OF assms] reduce_to_n_consts
  apply safe
  apply simp_all
  apply (metis map_append)
  apply (metis map_append)
  done

lemma reduce_to_n_label_emp1:
  assumes "(s,vs,($$*vcs)@[Label m [] es]) \<Down>k{(ls,r,i)} (s',vs',res)"
  shows "\<exists>res'. ((s,vs,es) \<Down>k{(m#ls,r,i)} (s',vs',res')) \<and>
         ((res' = RTrap \<and> res = RTrap) \<or>
          (\<exists>rvs. res' = RValue rvs \<and> res = RValue (vcs@rvs)) \<or>
          (\<exists>rvs. res' = RReturn rvs \<and> res = RReturn rvs) \<or>
          (\<exists>n rvs. res' = RBreak (Suc n) rvs \<and> res = RBreak n rvs) \<or>
          (\<exists>rvs. res' = RBreak 0 rvs \<and> res = RValue (vcs@rvs)))"
  using reduce_to_n_label_emp[OF assms]
  by auto

lemma invoke_native_imp_local_length:
  assumes "(s,vs,($$* vcs) @ [Invoke cl]) \<Down>k{(ls,r,i)} (s',vs',res)"
          "cl = Func_native j (t1s _> t2s) ts es"
  shows "length vcs \<ge> length t1s"
  using assms
proof (induction "(s,vs,($$* vcs) @ [Invoke cl])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (invoke_native cl j t1s t2s ts es ves vcs n m zs s vs k s' vs' res)
  thus ?case
    using inj_basic_econst
    by simp
next
  case (const_value s vs es k s' vs' res ves)
  thus ?case
    using consts_app_snoc[OF const_value(4)] consts_cons_last[of _ _ ves] is_const_def
    by fastforce
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    by (metis is_const_list)
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_nonvalue1(7)]
    by force
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    by (metis reduce_to_n_consts)
qed auto

lemma invoke_native_imp_local1:
  assumes "(s,vs,($$* vcs) @ [Invoke cl]) \<Down>k{(ls,r,i)} (s',vs',res)"
          "cl = Func_native j (t1s _> t2s) ts es"
          "length vcs = n"
          "length t1s = n"
          "length t2s = m"
          "(n_zeros ts = zs)"
  shows "(s,vs,[Local m j (vcs@zs) [$(Block ([] _> t2s) es)]]) \<Down>k{(ls,r,i)} (s',vs',res)"
  using assms
proof (induction "(s,vs,($$* vcs) @ [Invoke cl])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs rule: reduce_to_n.induct)
  case (invoke_native cl' j t1s t2s ts es ves' vcs n m zs s vs k s' vs' res)
  thus ?case
    using inj_basic_econst
    by auto
next
  case (const_value s vs es k s' vs' res ves)
  consider (1) "($$* ves) = ($$* vcs) @ [Invoke cl]" "es = []"
         | (2) "(\<exists>ves' ves''. ($$* ves) = ($$* ves') \<and> es = ($$* ves'') @ [Invoke cl] \<and> vcs = ves' @ ves'')"
    using consts_app_snoc[OF const_value(4)] inj_basic_econst
    by auto
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using consts_cons_last[OF 1(1)[symmetric]] is_const_def
      by simp
  next
    case 2
    then obtain ves' ves'' where ves'_def:"($$* ves) = $$* ves'"
                                           "es = ($$* ves'') @ [Invoke cl]"
                                           "vcs = ves' @ ves''"
      by blast
    show ?thesis
    proof (cases "length ves'' \<ge> length t1s")
      case True
      hence "ves'' = vcs"
        using ves'_def const_value(6,7)
        by auto
      thus ?thesis
        using const_value
              ves'_def inj_basic_econst
        by simp
    next
      case False
      thus ?thesis
        using invoke_native_imp_local_length const_value(1,5) ves'_def(2)
        by fastforce
    qed
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    apply simp
    apply (metis reduce_to_n_consts res_b.inject(1))
    done
next
  case (seq_nonvalue1 ves s vs es' k s' vs' res)
  show ?case
  proof -
    {
      fix ves' :: "v list" and ves'' :: "v list"
      assume a1: "ves = $$* ves'"
      assume a2: "(s, vs, ($$* ves'') @ [Invoke (Func_native j (t1s _> t2s) ts es)]) \<Down>k{(ls, r, i)} (s', vs', res)"
      assume a3: "length t1s = length (ves' @ ves'')"
      have "length t1s \<le> length ves''"
        using a2 by (simp add: invoke_native_imp_local_length)
      then have "ves'' = []"
        using a3 a1 by (simp add: local.seq_nonvalue1(5))
    }
    note a = this
    show ?case
      using consts_app_snoc[OF seq_nonvalue1(7)]
      apply simp
      apply safe
      apply (simp_all add: seq_nonvalue1.hyps(6))
      apply (metis a invoke_native_imp_local_length le_zero_eq length_0_conv self_append_conv2 seq_nonvalue1(2,3,8,9,10,11,12))
      done
  qed
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)] reduce_to_n_consts
    apply simp
    apply blast
    done
next
qed auto

lemma reduce_to_n_local:
  assumes "(s,vs,($$* vfs)@[Local m j vcs es]) \<Down>k{\<Gamma>} (s',vs',res)"
  shows "((\<nexists>rvs. res = RValue rvs) \<longrightarrow> ((s,vs,[Local m j vcs es]) \<Down>k{\<Gamma>} (s',vs',res))) \<and>
         (\<forall>rvs. res = RValue rvs \<longrightarrow> (\<exists>rvs1. rvs = vfs@rvs1 \<and> ((s,vs,[Local m j vcs es]) \<Down>k{\<Gamma>} (s',vs',RValue rvs1))))"
  using assms
proof (induction "(s,vs,($$* vfs)@[Local m j vcs es])" k \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res vfs rule: reduce_to_n.induct)
  case (local_value s lls es k n j s' lls' res vs \<Gamma>)
  thus ?case
    using reduce_to_n.local_value
    by simp
next
  case (const_value s vs es k \<Gamma> s' vs' res ves)
  thus ?case
    using consts_app_snoc[OF const_value(4)]
    apply simp
    apply safe
    apply simp_all
    apply (metis consts_cons_last(2) e.simps(12) e_type_const_unwrap)
    apply (metis inj_basic_econst map_injective)
    done
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    apply simp
    apply (metis reduce_to_n_consts res_b.inject(1))
    done
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  thus ?case
    using consts_app_snoc
    by blast
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    by (metis consts_app_snoc reduce_to_consts reduce_to_n_imp_reduce_to)
next
  case (local_trap s lls es k n j s' lls' vs \<Gamma>)
  thus ?case
    using reduce_to_n.local_trap
    by auto
next
  case (local_return s lls es k n j s' lls' rvs vs \<Gamma>)
  thus ?case
    apply simp
    apply (metis reduce_to_n.local_return)
    done
qed auto

lemma reduce_to_local:
  assumes "(s,vs,($$* vfs)@[Local m j vcs es]) \<Down>{\<Gamma>} (s',vs',res)"
  shows "((\<nexists>rvs. res = RValue rvs) \<longrightarrow> ((s,vs,[Local m j vcs es]) \<Down>{\<Gamma>} (s',vs',res))) \<and>
         (\<forall>rvs. res = RValue rvs \<longrightarrow> (\<exists>rvs1. rvs = vfs@rvs1 \<and> ((s,vs,[Local m j vcs es]) \<Down>{\<Gamma>} (s',vs',RValue rvs1))))"
  using reduce_to_n_local assms reduce_to_imp_reduce_to_n[OF assms]
  apply simp
  apply (metis reduce_to_n_imp_reduce_to reduce_to_n_local)
  done

lemma reduce_to_local_nonvalue:
  assumes "(s,vs,($$* vfs)@[Local m j vcs es]) \<Down>k{\<Gamma>} (s',vs',res)"
          "(\<nexists>rvs. res = RValue rvs)"
  shows "((s,vs,[Local m j vcs es]) \<Down>k{\<Gamma>} (s',vs',res))"
  using reduce_to_n_local[OF assms(1)] assms(2)
  by auto

lemma local_imp_body:
  assumes "(s,vs,($$*vfs)@[Local m j lvs les]) \<Down>k{(ls,r,i)} (s',vs',res)"
  shows "\<exists>lvs' lres. ((s,lvs,les) \<Down>k{([],Some m,j)} (s',lvs',lres)) \<and> vs = vs' \<and>
         ((lres = RTrap \<and> res = RTrap) \<or> (\<exists>rvs. ((lres = RValue rvs \<or> lres = RReturn rvs) \<and> res = RValue (vfs@rvs))))"
  using assms
proof (induction "(s,vs,($$*vfs)@[Local m j lvs les])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res les vfs rule: reduce_to_n.induct)
  case (const_value s vs es k s' vs' res ves)
  thus ?case
    using consts_app_snoc[OF const_value(4)]
    apply simp
    apply safe
    apply (metis consts_cons_last(2) e.simps(12) e_type_const_unwrap)
    apply (metis (no_types, lifting) append.assoc inj_basic_econst map_injective)
    done
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  consider (1) "es = ($$* vfs) @ [Local m j lvs les]" "es' = []"
         | (2) "(\<exists>ves' ves''. es = ($$* ves') \<and> es' = ($$* ves'') @ [Local m j lvs les] \<and> vfs = ves' @ ves'')"
    using consts_app_snoc[OF seq_value(7)]
    by blast
  thus ?case
  proof cases
    case 1
    thus ?thesis
      by (metis append.right_neutral reduce_to_n_consts seq_value.hyps(2,3))
  next
    case 2
    then obtain ves' ves'' where
     "es = $$* ves'"
     "es' = ($$* ves'') @ [Local m j lvs les] \<and> vfs = ves' @ ves''"
      by blast
    thus ?thesis
      using seq_value
      by (metis (no_types, lifting) reduce_to_n_consts res_b.inject(1))
  qed
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  thus ?case
    by (metis consts_app_snoc)
next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[OF seq_nonvalue2(5)]
    by (metis reduce_to_n_consts)
qed auto

lemma invoke_native_imp_local:
  assumes "(s,vs,($$* vfs) @ ($$* vcs) @ [Invoke cl]) \<Down>k{(ls,r,i)} (s',vs',res)"
          "cl = Func_native j (t1s _> t2s) ts es"
          "length vcs = n"
          "length t1s = n"
          "length t2s = m"
          "(n_zeros ts = zs)"
  shows "(s,vs,($$* vfs)@[Local m j (vcs@zs) [$(Block ([] _> t2s) es)]]) \<Down>k{(ls,r,i)} (s',vs',res)"
  using assms
proof (induction "(s,vs,($$* vfs) @ ($$* vcs) @ [Invoke cl])" k "(ls,r,i)" "(s',vs',res)" arbitrary: s vs s' vs' res vcs vfs rule: reduce_to_n.induct)
  case (invoke_native cl j t1s t2s ts es ves vcs' n m zs s vs k s' vs' res)
   thus ?case
   proof -
     {
       assume a1: "($$* vcs') = ($$* vfs) @ ($$* vcs) \<and> j = j \<and> t1s = t1s \<and> t2s = t2s \<and> ts = ts \<and> es = es"
       assume "ves = ($$* vfs) @ ($$* vcs)"
       assume a2: "length vcs = n"
       assume a3: "length vcs' = n"
       assume a4: "(s, vs, [Local m j (vcs' @ zs) [$Block ([] _> t2s) es]]) \<Down>k{(ls, r, i)} (s', vs', res)"
       have "($$* vfs) = []"
         using a3 a2 a1 by (metis (no_types) append_eq_append_conv length_map self_append_conv2)
       then have "(s, vs, ($$* vfs) @ [Local m j (vcs @ zs) [$Block ([] _> t2s) es]]) \<Down>k{(ls, r, i)} (s', vs', res)"
         using a4 a1 by (metis (no_types) reduce_to_n_consts reduce_to_n_consts1 res_b.inject(1) self_append_conv2)
     }
     thus ?thesis
       using invoke_native
       by auto
   qed
next
  case (const_value s vs es' k s' vs' res ves vcs)
  consider (1) "($$* ves) = ($$*vfs @ vcs) @ [Invoke cl]" "es' = []"
         | (2) "(\<exists>ves' ves''. ($$* ves) = ($$* ves') \<and> es' = ($$* ves'') @ [Invoke cl] \<and> vfs @ vcs = ves' @ ves'')"
    using consts_app_snoc[of "$$*ves" es' "vfs@vcs" "Invoke cl"] inj_basic_econst const_value(4)
    by auto
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using consts_cons_last[OF 1(1)[symmetric]] is_const_def
      by simp
  next
    case 2
    then obtain ves' ves'' where ves'_def:"($$* ves) = $$* ves'"
                                           "es' = ($$* ves'') @ [Invoke cl]"
                                           "vfs @ vcs = ves' @ ves''"
      by blast
    thus ?thesis
    proof (cases "length ves'' \<ge> length t1s")
      case True
      then obtain ves_l ves_l' where ves_l_def:"ves'' = ves_l @ ves_l'"
                                     "length ves_l' = length t1s"
        by (metis (full_types) append_take_drop_id diff_diff_cancel length_drop)
      hence 0:"ves_l' = vcs"
        using ves'_def const_value(6)
        by (metis append.assoc append_eq_append_conv const_value.prems(3))
      hence 1:"(s, vs, ($$* ves_l) @ [Local m j (vcs @ zs) [$Block ([] _> t2s) es]]) \<Down>k{(ls, r,i)} (s', vs', RValue res)"
        by (simp add: const_value.hyps(2) const_value.prems(1) const_value.prems(2) const_value.prems(3) const_value.prems(4) const_value.prems(5) ves'_def(2) ves_l_def(1))
      thus ?thesis
        using reduce_to_n.const_value[OF 1] ves_l_def ves'_def 0 inj_basic_econst 
              const_value.hyps(3)
        by auto
    next
      case False
      thus ?thesis
        using invoke_native_imp_local_length const_value(1,5) ves'_def(2)
        by fastforce
    qed
  qed
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[of es es' "vfs@vcs" "Invoke cl"]
    apply simp
    apply (metis reduce_to_n_consts res_b.inject(1))
    done
next
  case (seq_nonvalue1 ves s vs es k s' vs' res)
  consider (1) "ves = ($$* vfs @ vcs) @ [Invoke cl] \<and> es = []"
         | (2) "(\<exists>ves' ves''.
                ves = ($$* ves') \<and>
                es = ($$* ves'') @ [Invoke cl] \<and>
                vfs @ vcs = ves' @ ves'')"
    using consts_app_snoc[of ves es "vfs@vcs" "Invoke cl"] seq_nonvalue1(7)
    by fastforce
  thus ?case
  proof cases
    case 1
    thus ?thesis
      using seq_nonvalue1(6)
      by blast
  next
    case 2
    then obtain ves' ves'' where ves'_def:"ves = ($$* ves')"
                                          "es = ($$* ves'') @ [Invoke cl]"
                                          "vfs @ vcs = ves' @ ves''"
      by blast
    show ?thesis
    proof (cases "length ves'' \<ge> n")
      case True
      then obtain ves''_1 ves''_2 where ves''_is:"ves'' = ves''_1 @ ves''_2"
                                                 "length ves''_2 = n"
        by (metis append_take_drop_id diff_diff_cancel length_drop)
      hence "vcs = ves''_2 \<and> vfs = ves' @ ves''_1"
        using seq_nonvalue1(9)
        by (metis append_assoc append_eq_append_conv ves'_def(3))
      thus ?thesis
        using ves''_is ves'_def  seq_nonvalue1.hyps(1)
              seq_nonvalue1(3)[OF _ seq_nonvalue1(8,9,10,11,12), of ves''_1]
              reduce_to_n.seq_nonvalue1[OF _ _ seq_nonvalue1(4) , of "$$* (ves')"]
        apply (cases ves')
        apply simp_all
        done
    next
      case False
      thus ?thesis
        using invoke_native_imp_local_length seq_nonvalue1(2,10,8) ves'_def(2)
        by blast
    qed
  qed
  

next
  case (seq_nonvalue2 s vs es k s' vs' res es')
  thus ?case
    using consts_app_snoc[of es es' "vfs@vcs" "Invoke cl"]
    apply simp
    apply (metis reduce_to_n_consts)
    done
next
qed auto

lemma invoke_native_equiv_local:
  assumes "cl = Func_native j (t1s _> t2s) ts es"
          "length vcs = n"
          "length t1s = n"
          "length t2s = m"
          "(n_zeros ts = zs)"
  shows "((s,vs,($$* vcs) @ [Invoke cl]) \<Down>k{(ls,r,i)} (s',vs',res)) = ((s,vs,[Local m j (vcs@zs) [$(Block ([] _> t2s) es)]]) \<Down>k{(ls,r,i)} (s',vs',res))"
  using invoke_native_imp_local1[OF _ assms] reduce_to_n.invoke_native[OF assms(1) _ assms(2,3,4,5)]
  by blast

lemma local_context:
  assumes "((s,vs,[Local n i vls es]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "((s,vs,[Local n i vls es]) \<Down>k{\<Gamma>'} (s',vs',res))"
  using assms
proof (induction "(s,vs,[Local n i vls es])" k \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res rule: reduce_to_n.induct)
  case (const_value s vs es' k \<Gamma> s' vs' res ves)
  thus ?case
    using consts_app_snoc[of "($$* ves)" "es" "[]" "Local n i vls es"]
          consts_cons_last[of "[]" "Local n i vls es" ves]
    apply (simp add: is_const_def)
    apply (metis (no_types, lifting) Cons_eq_append_conv Nil_is_append_conv append_self_conv inj_basic_econst map_append map_injective)
    done
next
  case (local_value k lls' res \<Gamma>)
  thus ?case
    using reduce_to_n.local_value
    by blast
next
  case (seq_value s vs es' k \<Gamma> s'' vs'' res'' es'' s' vs' res)
  consider (1) "es' = [Local n i vls es]" "es'' = []" | (2) "es' = []" "es'' = [Local n i vls es]"
    using seq_value(7)
    unfolding append_eq_Cons_conv
    by fastforce
  thus ?case
    apply (cases)
    apply (metis append_Nil2 reduce_to_consts reduce_to_n_imp_reduce_to seq_value.hyps(2) seq_value.hyps(3))
    apply (metis append.right_neutral consts_app_ex(2) is_const_list seq_value.hyps(5))
    done
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  thus ?case
    by (meson append_eq_Cons_conv append_is_Nil_conv)
    
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    by (metis Cons_eq_append_conv Nil_is_append_conv reduce_to_n_emp)
next
  case (local_trap k lls' \<Gamma>)
  thus ?case
    using reduce_to_n.local_trap
    by blast
next
  case (local_return k lls' rvs \<Gamma>)
  thus ?case
    using reduce_to_n.local_return
    by blast
qed auto

lemma invoke_context:
  assumes "((s,vs,($$*ves)@[(Invoke cl)]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "((s,vs,($$*ves)@[(Invoke cl)]) \<Down>k{\<Gamma>'} (s',vs',res))"
  using assms
proof (induction "(s,vs,($$*ves)@[(Invoke cl)])" k \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res ves rule: reduce_to_n.induct)
  case (invoke_native cl j t1s t2s ts es ves' vcs n m zs s vs k ls r i s' vs' res)
  show ?case
    using local_context[OF invoke_native(7), of \<Gamma>'] reduce_to_n.invoke_native[OF invoke_native(1,2,3,4,5,6)]
    apply (cases \<Gamma>')
    apply (auto simp add: invoke_native.hyps(9))
    done
next
  case (invoke_host_Some cl t1s t2s f ves vcs n m s hs s' vcs' vs k ls r i)
  show ?case
    using reduce_to_n.invoke_host_Some[OF invoke_host_Some(1,2,3,4,5,6)]
    apply (cases \<Gamma>')
    apply (auto simp add: invoke_host_Some.hyps(7))
    done
next
  case (invoke_host_None cl t1s t2s f ves vcs n m s vs k ls r i)
  thus ?case
    using reduce_to_n.invoke_host_None[OF invoke_host_None(1,2,3,4,5)]
    apply (cases \<Gamma>')
    apply (auto simp add: invoke_host_None.hyps(6))
    done
next
  case (const_value s vs es k \<Gamma> s' vs' res ves ves')
  thus ?case
    using consts_app_snoc[OF const_value(4)]
    by (metis (no_types, lifting) const_list_cons_last(2) e.distinct(3) e_type_const_unwrap is_const_list reduce_to_n.const_value)
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    by (metis (no_types, lifting) reduce_to_consts reduce_to_n_imp_reduce_to res_b.inject(1))
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  thus ?case
    by (metis consts_app_snoc reduce_to_n.seq_nonvalue1)
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    by (metis consts_app_snoc reduce_to_consts reduce_to_n_imp_reduce_to)
qed auto

lemma calln_context: "((s,vs,($$*ves)@[$(Call j)]) \<Down>k{(ls,r,i)} (s',vs',res)) = ((s,vs,($$*ves)@[$(Call j)]) \<Down>k{(ls',r',i)} (s',vs',res))"
  apply (cases k)
  apply(metis call0)
  apply (metis invoke_context calln)
  done

lemma reduce_to_length_globs:
  assumes "(s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)"
  shows "length (s.globs s) \<le> length (s.globs s')"
  using assms
proof (induction "(s,vs,es)" "k" "\<Gamma>" "(s',vs',res)" arbitrary: s s' es res vs vs' rule: reduce_to_n.induct)
  case (set_global s i j v s' vs k ls r)
  thus ?case
    unfolding supdate_glob_def Let_def supdate_glob_s_def
    using length_list_update[of "s.globs s"]
    by auto
next
  case (invoke_host_Some cl t1s t2s f ves vcs n m s hs s' vcs' vs k ls r i)
  show ?case
    using host_apply_preserve_store1[OF invoke_host_Some(6)] list_all2_lengthD
    unfolding store_extension.simps
    by fastforce
qed auto

lemma reduce_to_funcs:
  assumes "(s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)"
  shows "\<exists>cls. (s.funcs s)@cls = (s.funcs s')"
  using assms
proof (induction "(s,vs,es)" "k" "\<Gamma>" "(s',vs',res)" arbitrary: s s' es res vs vs' rule: reduce_to_n.induct)
  case (set_global s i j v s' vs k ls r)
  thus ?case
    unfolding supdate_glob_def Let_def supdate_glob_s_def
    by auto
next
  case (invoke_host_Some cl t1s t2s f ves vcs n m s hs s' vcs' vs k ls r i)
  show ?case
    using host_apply_preserve_store1[OF invoke_host_Some(6)] list_all2_lengthD
    unfolding store_extension.simps
    by fastforce
next
  case (label_break_nil s vs es k n ls r i s'' vs'' bvs vcs les s' vs' res)
  thus ?case
    by (metis append_assoc)
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    by (metis append_assoc)
qed auto

lemma local_value_trap:
  assumes "((s,vs,[Local n i vls es]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "\<exists>vrs. res = RValue vrs \<or> res = RTrap"
  using assms
proof (induction "(s,vs,[Local n i vls es])" k \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res rule: reduce_to_n.induct)
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  consider (1) "es = []" | (2) "es' = []"
    using seq_value(7)
    by (metis Cons_eq_append_conv Nil_is_append_conv)
  thus ?case
    apply cases
    apply (metis append_self_conv2 local.seq_value(1) map_append reduce_to_n_emp res_b.inject(1) seq_value.hyps(4,7))
    apply (metis reduce_to_consts reduce_to_n_imp_reduce_to self_append_conv seq_value.hyps(3))
    done
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  thus ?case
    by (meson append_eq_Cons_conv append_is_Nil_conv)
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    by (metis append_eq_Cons_conv append_is_Nil_conv reduce_to_n_emp)
qed auto

lemma reduce_to_n_br_if:
  assumes "((s,vs,($$*vesf)@[$C ConstInt32 c, $Br_if j]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "(((s,vs,($$*vesf)@[$Br j]) \<Down>k{\<Gamma>} (s',vs',res)) \<and> int_ne c 0) \<or> (s = s' \<and> vs = vs' \<and> int_eq c 0 \<and> res = RValue vesf)"
  using assms
proof (induction "(s,vs,($$*vesf)@[$C ConstInt32 c, $Br_if j])" k \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res vesf rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves)
  consider (1) "es = [$Br_if j]" "ves = vesf @ [ConstInt32 c]"
         | (2) ves'' where "es = ($$* ves'') @ [$C ConstInt32 c, $Br_if j]" "vesf = ves @ ves''"
    using consts_app_snoc_1[OF const_value(4)]
    by (fastforce simp add: is_const_def)
  thus ?case
  proof (cases)
    case 1
    thus ?thesis
      by (metis const_value.hyps(1) no_reduce_to_n)
  next
    case 2
    thus ?thesis
      using const_value(2)[OF 2(1)]
      by (metis append_assoc const_value.hyps(3) map_append reduce_to_n.const_value res_b.inject(1))
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    by (metis b_e.distinct(403) consts_app_snoc_1_const_list e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  obtain vcs where ves_is:"ves = $$*vcs"
    using seq_nonvalue1(1)
    by (metis e_type_const_conv_vs)
  then consider (1) "es = [$Br_if j] \<and> vcs = vesf @ [ConstInt32 c]"
              | (2) ves'' where"es = ($$* ves'') @ [$C ConstInt32 c, $Br_if j]" "vesf = vcs @ ves''"
    using consts_app_snoc_1[of vcs es vesf "ConstInt32 c" "$Br_if j"] seq_nonvalue1(7)
    by (metis b_e.distinct(403) e.inject(1) e_type_const_unwrap)
  thus ?case
  proof cases
    case 1
    thus ?thesis
      by (metis no_reduce_to_n seq_nonvalue1.hyps(2))
  next
    case 2
    thus ?thesis
      using seq_nonvalue1(3)[OF 2(1)]
      apply simp
      apply (metis append_is_Nil_conv not_Cons_self2 reduce_to_n.seq_nonvalue1 seq_nonvalue1.hyps(1,4,5) ves_is)
      done
  qed
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma reduce_to_n_br_table:
  assumes "((s,vs,($$*vesf)@[$C ConstInt32 c, $Br_table js j]) \<Down>k{\<Gamma>} (s',vs',res))"
          "(nat_of_int c) = c'"
  shows "(((s,vs,($$*vesf)@[$Br (js!c')]) \<Down>k{\<Gamma>} (s',vs',res)) \<and> c' < length js) \<or> (((s,vs,($$*vesf)@[$Br j]) \<Down>k{\<Gamma>} (s',vs',res)) \<and> c' \<ge> length js)"
  using assms
proof (induction "(s,vs,($$*vesf)@[$C ConstInt32 c, $Br_table js j])" k \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res vesf rule: reduce_to_n.induct)
  case (const_value s vs es k \<Gamma> s' vs' res ves)
  consider (1) "es = [$Br_table js j]" "ves = vesf @ [ConstInt32 c]"
         | (2) ves'' where "es = ($$* ves'') @ [$C ConstInt32 c, $Br_table js j]" "vesf = ves @ ves''"
    using consts_app_snoc_1[OF const_value(4)]
    by (fastforce simp add: is_const_def)
  thus ?case
  proof (cases)
    case 1
    thus ?thesis
      using no_reduce_to_n const_value(1)
      by metis
  next
    case 2
    thus ?thesis
      using const_value(2)[OF 2(1)]
      apply simp
      apply (metis const_value.hyps(3) const_value.prems reduce_to_n.const_value)
      done
  qed
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    by (metis b_e.distinct(439) consts_app_snoc_1_const_list e.inject(1) e_type_const_unwrap)
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  obtain vcs where ves_is:"ves = $$*vcs"
    using seq_nonvalue1(1)
    by (metis e_type_const_conv_vs)
  then consider (1) "es = [$Br_table js j] \<and> vcs = vesf @ [ConstInt32 c]"
              | (2) ves'' where"es = ($$* ves'') @ [$C ConstInt32 c, $Br_table js j]" "vesf = vcs @ ves''"
    using consts_app_snoc_1[of vcs es vesf "ConstInt32 c" "$Br_table js j"] seq_nonvalue1(7)
    by (metis b_e.distinct(439) e.inject(1) e_type_const_unwrap)
  thus ?case
  proof cases
    case 1
    thus ?thesis
      by (metis no_reduce_to_n seq_nonvalue1.hyps(2))
  next
    case 2
    thus ?thesis
      using seq_nonvalue1(3)[OF 2(1)]
      apply simp
      apply (metis append_is_Nil_conv not_Cons_self2 reduce_to_n.seq_nonvalue1 seq_nonvalue1.hyps(1,4,5) seq_nonvalue1.prems ves_is)
      done
  qed
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  have "\<not> const_list es"
    using seq_nonvalue2(1,3) reduce_to_consts e_type_const_conv_vs reduce_to_n_imp_reduce_to
    by metis
  thus ?case
    using consts_app_snoc_1_const_list[OF seq_nonvalue2(5)] seq_nonvalue2(4)
    by (simp add: is_const_def)
qed auto

lemma invoke_value_trap:
  assumes "((s,vs,($$*ves)@[(Invoke cl)]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "\<exists>vrs. res = RValue vrs \<or> res = RTrap"
  using assms
proof (induction "(s,vs,($$*ves)@[(Invoke cl)])" k \<Gamma> "(s',vs',res)" arbitrary: s vs s' vs' res ves rule: reduce_to_n.induct)
  case (invoke_native cl j t1s t2s ts es ves vcs n m zs s vs k ls r i s' vs' res)
  thus ?case
    using local_value_trap
    by blast
next
  case (seq_value s vs es k \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    using consts_app_snoc[OF seq_value(7)]
    apply simp
    apply (metis reduce_to_consts reduce_to_n_imp_reduce_to res_b.inject(1))
    done
next
  case (seq_nonvalue1 ves s vs es k \<Gamma> s' vs' res)
  thus ?case
    using consts_app_snoc
    by blast
next
  case (seq_nonvalue2 s vs es k \<Gamma> s' vs' res es')
  thus ?case
    by (metis consts_app_snoc reduce_to_consts reduce_to_n_imp_reduce_to)
qed auto

lemma call_value_trap:
  assumes "((s,vs,($$*ves)@[$(Call j)]) \<Down>k{\<Gamma>} (s',vs',res))"
  shows "\<exists>vrs. res = RValue vrs \<or> res = RTrap"
proof (cases k)
  case 0
  thus ?thesis
    using call0 assms
    by metis
next
  case (Suc k')
  thus ?thesis
    using assms calln invoke_value_trap
    apply (cases \<Gamma>)
    apply simp
    done
qed

lemma reduce_to_apps:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
          "($$*ves') @ [e] = es@es'"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
proof -
  consider (1) "es = es@es'" | (2) "\<exists>ves. es = $$* ves"
    using consts_app_snoc[of es es' ves' e] assms(2)
    by fastforce
  thus ?thesis
  proof cases
    case 1
    thus ?thesis
      using assms(1)
      by (metis reduce_to_n_consts1 self_append_conv)
  next
    case 2
    thus ?thesis
      using reduce_to_n_consts1 assms(1)
      by blast
  qed
qed

lemma reduce_to_app0:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
          "[e] = es@es'"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
  using assms(2) reduce_to_apps[OF assms(1), of "[]"]
  by auto

lemma reduce_to_app1:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
          "[$C v, e] = es@es'"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
  using assms(2) reduce_to_apps[OF assms(1), of "[v]"]
  by fastforce

lemma reduce_to_app2:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
          "[$C v, $C v', e] = es@es'"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
  using assms(2) reduce_to_apps[OF assms(1), of "[v,v']"]
  by fastforce

lemma reduce_to_app3:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
          "[$C v, $C v', $C v'', e] = es@es'"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
  using assms(2) reduce_to_apps[OF assms(1), of "[v,v',v'']"]
  by fastforce

lemma reduce_to_apps_const_list:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
          "const_list ves'"
          "(ves') @ [e] = es@es'"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
proof -
  consider (1) "es = es@es'" | (2) "\<exists>ves. es = $$* ves"
    using consts_app_snoc[of es es' _ e]  e_type_const_conv_vs[OF assms(2)]
    by (metis assms(3))
  thus ?thesis
  proof cases
    case 1
    thus ?thesis
      using assms(1)
      by (metis reduce_to_n_consts1 self_append_conv)
  next
    case 2
    thus ?thesis
      using reduce_to_n_consts1 assms(1)
      by blast
  qed
qed

lemma reduce_to_apps_const_list_v:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
          "const_list ves'"
          "(ves') @ [$C v, e] = es@es'"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
proof -
  obtain ves where "($$* ves) = (ves') @ [$C v]"
  proof -
    assume a1: "\<And>ves. ($$* ves) = ves' @ [$C v] \<Longrightarrow> thesis"
    obtain vvs :: "v list" where
      "\<forall>vs. ves' @ ($$* vs) = $$* vvs @ vs"
      using e_type_const_conv_vs[OF assms(2)] by moura
    then show ?thesis
      using a1 by (metis (no_types) list.simps(8) list.simps(9))
  qed
  then consider (1) "es' = []" | (2) "\<exists>ves. es = $$* ves"
    using consts_app_snoc[of es es' ves e] assms(3)
    by fastforce
  thus ?thesis
  proof cases
    case 1
    thus ?thesis
      using assms(1)
      by (metis reduce_to_n_consts1 self_append_conv)
  next
    case 2
    thus ?thesis
      using reduce_to_n_consts1 assms(1)
      by blast
  qed
qed

lemma reduce_to_app_disj:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
          "[e] = es@es' \<or>
           [$C v, e] = es@es' \<or>
           [$C v, $C v', e] = es@es' \<or>
           [$C v, $C v', $C v'', e] = es@es' \<or>
           ($$*ves') @ [e] = es@es' \<or>
           (const_list ves'' \<and> (ves'') @ [e] = es@es') \<or>
           (const_list ves''' \<and> (ves''') @ [$C v''', e] = es@es')"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
  using assms
  apply safe
  using reduce_to_app0 apply (blast+)[2]
  using reduce_to_app1 apply (blast+)[2]
  using reduce_to_app2 apply (blast+)[2]
  using reduce_to_app3 apply (blast+)[2]
  using reduce_to_apps apply (blast+)[2]
  using reduce_to_apps_const_list apply (blast+)[2]
  using reduce_to_apps_const_list_v apply (blast+)[2]
  done

lemma reduce_to_n_app:
  assumes "(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>k{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>k{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
  using assms assms
proof (induction "(s,vs,es@es')" "k" "\<Gamma>" "(s',vs',res)" arbitrary: s vs es es' s' vs' res rule: reduce_to_n.induct)
  case (emp s vs k \<Gamma>)
  thus ?case
    by fastforce
next
  case (if_false n ves s vs tf e2s k \<Gamma> s' vs' res e1s)
  thus ?case
    using reduce_to_apps_const_list_v
    by auto
next
  case (if_true n ves s vs tf e1s k \<Gamma> s' vs' res e2s)
  thus ?case
    using reduce_to_apps_const_list_v
    by auto
next
  case (tee_local v s vs i k \<Gamma> s' vs' res)
  thus ?case
    using e_type_const_unwrap[of v] reduce_to_app1
    by fast
next
  case (const_value s vs es'' k \<Gamma> s' vs' res ves es)
  consider (1) "(\<exists>ves' ves''.
                  es = ($$* ves') \<and>
                  es' = ($$* ves'') @ es'' \<and>
                  ves = ves' @ ves'')"
    | (2) "(\<exists>es_1 es_2.
              es = ($$* ves) @ es_1 \<and>
              es' = es_2 \<and>
              es'' = es_1 @ es_2)"
    using consts_app[OF const_value(4)[symmetric]]
    by blast
  thus ?case
  proof (cases)
    case 1
    thus ?thesis
      using reduce_to_n_consts1 const_value
      by blast
  next
    case 2
    then obtain es_1 es_2 where es_1_def:"es = ($$* ves) @ es_1"
                                          "es' = es_2"
                                          "es'' = es_1 @ es_2"
      by blast
    obtain s'' vs'' res' where s''_def:"((s, vs, es_1) \<Down>k{\<Gamma>} (s'', vs'', RValue res'))"
                               "(s'', vs'', ($$* res') @ es_2) \<Down>k{\<Gamma>} (s', vs', RValue res)"
      using const_value(1) const_value(2)[OF es_1_def(3)] es_1_def(3)
      by blast
    hence "((s'', vs'', ($$* res') @  es_2) \<Down>k{\<Gamma>} (s', vs', RValue res))"
      using s''_def
      by blast
    hence "((s'', vs'', ($$* ves) @ ($$* res') @  es_2) \<Down>k{\<Gamma>} (s', vs', RValue (ves@res)))"
      by (simp add: const_value.hyps(3) reduce_to_n.const_value)
    moreover
    have "(s, vs, es) \<Down>k{\<Gamma>} (s'', vs'', RValue (ves@res'))"
      using s''_def(1) es_1_def(1)
      by (simp add: const_value.hyps(3) reduce_to_n.const_value)
    ultimately
    show ?thesis
      using es_1_def(2)
      by fastforce
  qed
next
  case (seq_value s vs es'' k \<Gamma> s'' vs'' res'' es''' s' vs' res es es')
  consider (1) "\<exists>us. (es'' = es @ us \<and> us @ es''' = es')" | (2) "\<exists>us. (es'' @ us = es \<and> es''' = us @ es')"
    using seq_value(7) append_eq_append_conv2[of es'' es''' es es']
    by blast
  thus ?case
  proof (cases)
    case 1
    then obtain us where us_def:"es'' = es @ us"
                                "us @ es''' = es'"
      by blast
    consider (1) "(\<exists>s''a vs''a rvs.
                    ((s, vs, es) \<Down>k{\<Gamma>} (s''a, vs''a, RValue rvs)) \<and>
                    ((s''a, vs''a, ($$* rvs) @ us) \<Down>k{\<Gamma>} (s'', vs'', RValue res'')))"
      | (2) "((s, vs, es) \<Down>k{\<Gamma>} (s'', vs'', RValue res''))"
            "(\<nexists>rvs. RValue res'' = RValue rvs)"
      using seq_value(2)[OF us_def(1)] seq_value.hyps(1) us_def(1)
      by blast
    thus ?thesis
    proof cases
      case 1
      then obtain s''a vs''a rvs where s''a_def:
       "((s, vs, es) \<Down>k{\<Gamma>} (s''a, vs''a, RValue rvs))"
       "((s''a, vs''a, ($$* rvs) @ us) \<Down>k{\<Gamma>} (s'', vs'', RValue res''))"
        by blast
      have "(s''a, vs''a, (($$* rvs) @ us) @ es''') \<Down>k{\<Gamma>} (s', vs', res)"
        using reduce_to_n.seq_value[OF s''a_def(2) seq_value(3)]
        by (metis e_type_const_conv_vs reduce_to_consts reduce_to_n_imp_reduce_to res_b.inject(1) s''a_def(2) seq_value.hyps(3,6))
      thus ?thesis
        using s''a_def(1) us_def(2)
        by auto
    next
      case 2
      thus ?thesis
        by blast
    qed
  next
    case 2
    then obtain us where us_def:"es'' @ us = es"
                                "es''' = us @ es'"
      by blast
    consider (1) "\<exists>s''a vs''a rvs. (((s'', vs'', ($$* res'') @ us) \<Down>k{\<Gamma>} (s''a, vs''a,  RValue rvs)) \<and>
           ((s''a, vs''a, ($$* rvs) @ es') \<Down>k{\<Gamma>} (s', vs', res)))"
      | (2) "((s'', vs'', ($$* res'') @ us) \<Down>k{\<Gamma>} (s', vs', res)) \<and> (\<nexists>rvs. res = RValue rvs)"
      using seq_value(4)[of "($$* res'') @ us" "es'"] seq_value.hyps(3) us_def(2)
      by auto
    thus ?thesis
      using reduce_to_n.seq_value seq_value.hyps(1) us_def(1)
      apply cases
      apply (metis append.assoc append_Nil2 seq_value.hyps(3) seq_value.hyps(5) us_def(2))
      apply (metis append_Nil2 self_append_conv2 seq_value.hyps(3) seq_value.hyps(5) us_def(2))
      done
  qed
next
  case (seq_nonvalue1 ves s vs es'' k \<Gamma> s' vs' res)
  consider (1) "(\<exists>us. ves = es @ us \<and> us @ es'' = es')"
         | (2) "(\<exists>us. ves @ us = es \<and> es'' = us @ es')"
    using append_eq_append_conv2[of ves es'' es es'] seq_nonvalue1(7)
    by blast
  thus ?case
  proof cases
    case 1
    thus ?thesis
      by (metis (no_types, lifting) consts_app_ex(1) e_type_const_conv_vs reduce_to_n_consts1 seq_nonvalue1.hyps(1) seq_nonvalue1.prems)
  next
    case 2
    then obtain us where us_def:"ves @ us = es" "es'' = us @ es'"
      by blast
    consider
      (1) s'' vs'' rvs where "(((s, vs, us) \<Down>k{\<Gamma>} (s'', vs'', RValue rvs)) \<and> ((s'', vs'', ($$* rvs) @ es') \<Down>k{\<Gamma>} (s', vs', res)))"
    | (2) "(((s, vs, us) \<Down>k{\<Gamma>} (s', vs', res)) \<and> (\<nexists>rvs. res = RValue rvs))"
      using seq_nonvalue1(3)[OF us_def(2)] seq_nonvalue1(2) us_def(2)
      by fastforce
    thus ?thesis
    proof (cases)
      case 1
      obtain vcs where ves_is:"ves = $$* vcs"
        using e_type_const_conv_vs seq_nonvalue1.hyps(1)
        by blast
      hence "((s, vs, ves@us) \<Down>k{\<Gamma>} (s'', vs'', RValue (vcs@rvs)))"
        using "1" reduce_to_n.const_value seq_nonvalue1.hyps(5)
        by auto
      moreover
      have "((s'', vs'', ($$* (vcs@rvs)) @ es') \<Down>k{\<Gamma>} (s', vs', res))"
        using 1 reduce_to_n.seq_nonvalue1[OF _ _ seq_nonvalue1(4), of ves] ves_is
        by (metis append_assoc map_append reduce_to_n_emp seq_nonvalue1.hyps(1,4,5))
      ultimately
      show ?thesis
        using us_def(1)
        by blast
    next
      case 2
      thus ?thesis
        by (metis reduce_to_n.seq_nonvalue1 reduce_to_n_emp seq_nonvalue1.hyps(1,5) us_def(1))
    qed
  qed
next
  case (seq_nonvalue2 s vs es'' k \<Gamma> s' vs' res es''')
  thus ?case
    using append_eq_append_conv2[of es'' es''' es es']
    apply simp
    apply safe
    apply (metis append_assoc reduce_to_n.seq_nonvalue2)
    apply (meson reduce_to_n.seq_nonvalue2)
    apply (metis append.right_neutral reduce_to_n.seq_nonvalue2)
    done
next
qed (insert reduce_to_app_disj, (fast+))
(* terminal method long-running *)

lemma reduce_to_call: "((s,vs,($$*ves)@[$(Call j)]) \<Down>{(ls,r,i)} (s',vs',res)) = ((s,vs,($$*ves)@[(Invoke (sfunc s i j))]) \<Down>{(ls,r,i)} (s',vs',res))"
proof -
  {
    assume local_assms:"((s,vs,($$*ves)@[$(Call j)]) \<Down>{(ls,r,i)} (s',vs',res))"
    have "\<exists>k. ((s,vs,($$*ves)@[$(Call j)]) \<Down>(Suc k){(ls,r,i)} (s',vs',res))"
      using call0 reduce_to_imp_reduce_to_n[OF local_assms]
      by (metis not0_implies_Suc)
  }
  thus ?thesis
    using calln reduce_to.call is_const_list reduce_to_n_imp_reduce_to
    by auto
qed

lemma reduce_to_app:
  assumes "(s,vs,es@es') \<Down>{\<Gamma>} (s',vs',res)"
  shows "(\<exists>s'' vs'' rvs. ((s,vs,es) \<Down>{\<Gamma>} (s'',vs'',RValue rvs)) \<and> ((s'',vs'',($$*rvs)@es') \<Down>{\<Gamma>} (s',vs',res))) \<or>
         (((s,vs,es) \<Down>{\<Gamma>} (s',vs',res)) \<and> (\<nexists>rvs. res = RValue rvs))"
proof -
  obtain k where k_is:"(s,vs,es@es') \<Down>k{\<Gamma>} (s',vs',res)"
    using assms reduce_to_iff_reduce_to_n
    by blast
  show ?thesis
    using reduce_to_n_app[OF k_is] reduce_to_n_imp_reduce_to
    by blast
qed

lemma reduce_to_n_seq_value_all:
  assumes "(s,vs,es) \<Down>k{\<Gamma>} (s'',vs'',RValue res'')"
          "(s'',vs'',($$* res'') @ es') \<Down>k{\<Gamma>} (s',vs',res)"
  shows "(s,vs,es @ es') \<Down>k{\<Gamma>} (s',vs',res)"
proof (cases "es' = []")
  case True
  thus ?thesis
    using assms
    by (metis append_self_conv reduce_to_n_consts)
next
  case False
  show ?thesis
  proof (cases "const_list es")
    case True
    thus ?thesis
      using assms(1,2) e_type_const_conv_vs reduce_to_consts reduce_to_iff_reduce_to_n
      by blast
  next
    case False
    thus ?thesis
      by (metis append_Nil2 assms(1,2) reduce_to_n.seq_value reduce_to_n_consts)
  qed
qed

lemma reduce_to_seq_value_all:
  assumes "(s,vs,es) \<Down>{\<Gamma>} (s'',vs'',RValue res'')"
          "(s'',vs'',($$* res'') @ es') \<Down>{\<Gamma>} (s',vs',res)"
  shows "(s,vs,es @ es') \<Down>{\<Gamma>} (s',vs',res)"
  using assms reduce_to_n_seq_value_all
  by (metis (no_types, lifting) append_Nil2 e_type_const_conv_vs reduce_to.seq_value
                                reduce_to_iff_reduce_to_n reduce_to_n_consts res_b.inject(1))

lemma reduce_to_L0:
  assumes "const_list ves"
          "(s,vs,es) \<Down>{\<Gamma>} (s',vs',res)"
          "\<nexists>rvs. res = RValue rvs"
  shows "(s,vs,ves @ es@ es') \<Down>{\<Gamma>} (s',vs',res)"
proof -
  have 1:"(s,vs,ves@es) \<Down>{\<Gamma>} (s',vs',res)"
    using reduce_to.seq_nonvalue1[OF assms(1,2,3)] assms(2)
    apply (cases ves)
    apply simp_all
    apply (metis append.left_neutral assms(3) reduce_to.seq_nonvalue2)
    done
  show ?thesis
    using reduce_to.seq_nonvalue2[OF 1 assms(3)] 1
    apply (cases es')
    apply simp_all
    done
qed

lemma reduce_to_L0_consts_left:
  assumes "(s,vs,es) \<Down>{\<Gamma>} (s',vs',RValue rvs)"
  shows "(s,vs,($$*vcs)@es) \<Down>{\<Gamma>} (s',vs',RValue (vcs@rvs))"
proof -
  show ?thesis
  proof (cases "vcs = []")
    case False
    thus ?thesis
      using reduce_to.const_value assms
      by auto
  qed (auto simp add: assms)
qed

lemma reduce_to_L0_consts_left_trap:
  assumes "(s,vs,es) \<Down>{\<Gamma>} (s',vs',RTrap)"
  shows "(s,vs,($$*vcs)@es) \<Down>{\<Gamma>} (s',vs',RTrap)"
proof -
  show ?thesis
  proof (cases "vcs = []")
    case False
    thus ?thesis
      using reduce_to.seq_nonvalue1 assms
      by (metis is_const_list reduce_to_iff_reduce_to_n reduce_to_n_emp res_b.distinct(5) self_append_conv2)
  qed (auto simp add: assms)
qed

lemma reduce_to_trap_L0_left:
  assumes "((s, vs, ($$* vcsf) @ [Trap]) \<Down>{\<Gamma>} (s', vs', res))"
  shows "((s, vs, [Trap]) \<Down>{\<Gamma>} (s', vs', res))"
  using assms
proof (induction "(s, vs, ($$* vcsf) @ [Trap])" \<Gamma> "(s', vs', res)" arbitrary: s vs s' vs' res vcsf rule: reduce_to.induct)
  case (const_value s vs es \<Gamma> s' vs' res ves)
  thus ?case
    by (metis (no_types, lifting) const_list_cons_last(2) consts_app_snoc e.distinct(1) e_type_const_unwrap is_const_list reduce_to_trap res_b.distinct(5))
next
  case (seq_value s vs es \<Gamma> s'' vs'' res'' es' s' vs' res)
  thus ?case
    by (metis consts_app_snoc is_const_list)
next
  case (seq_nonvalue1 ves s vs es \<Gamma> s' vs' res)
  thus ?case
    using consts_app_snoc
    by blast
next
  case (seq_nonvalue2 s vs es \<Gamma> s' vs' res es')
  thus ?case
    apply simp
    apply (metis consts_app_snoc reduce_to_consts)
    done
next
  case (trap s vs \<Gamma>)
  thus ?case
    using reduce_to.trap
    by blast
qed auto

lemma reduce_to_label_emp:
  assumes "(s,vs,($$*vcs)@[Label m [] es]) \<Down>{(ls,r,i)} (s',vs',res)"
  shows "(((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RTrap)) \<and> res = RTrap) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RReturn rvs)) \<and> res = RReturn rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RValue rvs)) \<and> res = RValue (vcs@rvs)) \<or>
         (\<exists>n rvs. ((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RBreak (Suc n) rvs)) \<and> res = RBreak n rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>{(m#ls,r,i)} (s',vs',RBreak 0 rvs)) \<and> res = RValue (vcs@rvs))"
  using reduce_to_n_label_emp reduce_to_imp_reduce_to_n[OF assms] reduce_to_n_imp_reduce_to
  apply (cases res)
  apply simp_all
     apply blast+
  done

lemma reduce_to_label_emp1:
  assumes "(s,vs,($$*vcs)@[Label m [] es]) \<Down>{(ls,r,i)} (s',vs',res)"
  shows "((\<nexists>rvs. res = RValue rvs) \<longrightarrow> ((s,vs,[Label m [] es]) \<Down>{(ls,r,i)} (s',vs',res))) \<and>
         (\<forall>rvs. (res = RValue rvs \<longrightarrow> (\<exists>rvs'. rvs = vcs@rvs' \<and> ((s,vs,[Label m [] es]) \<Down>{(ls,r,i)} (s',vs',RValue rvs')))))"
  using reduce_to_label_emp[OF assms]
  apply (cases res)
  apply simp_all
  apply safe
  apply simp_all
  apply (simp add: reduce_to.label_value)
  apply (insert reduce_to.label_break_nil[of _ _ _ _ _ _ _ _ _ _ _"[]"])[1]
  apply simp
  apply (metis append_self_conv2 map_append reduce_to_consts1 self_append_conv)
  apply (simp add: reduce_to.label_break_suc)
  apply (simp add: reduce_to.label_return)
  apply (simp add: reduce_to.label_trap)
  done
(*
lemma reduce_to_label_loop:
  assumes "(s,locs,($$*vcsf) @ es) \<Down>{(ls, r, i)} (s',locs',res)"
          "es = ($$*vcs) @ [$(Loop (t1s _> t2s) b_es)] \<or>
           es = [(Label n [$(Loop (t1s _> t2s) b_es)] (($$*vcs)@ ($*b_es)))]"
          "length ($$*vcs) = n"
          "length t1s = n"
  shows "(((s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RTrap)) \<and> res = RTrap) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RReturn rvs)) \<and> res = RReturn rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RValue rvs)) \<and> res = RValue (vcs@rvs)) \<or>
         (\<exists>n rvs. ((s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RBreak (Suc n) rvs)) \<and> res = RBreak n rvs) \<or>
         (\<exists>rvs. ((s,vs,es) \<Down>{(n#ls,r,i)} (s',vs',RBreak 0 rvs)) \<and> res = RValue (vcs@rvs))"
*)
lemma reduce_to_label_loop1:
  assumes "(s,locs,($$*vcsf) @ es) \<Down>{(ls, r, i)} (s',locs',res)"
          "es = ($$*vcs) @ [$(Loop (t1s _> t2s) b_es)] \<or>
           es = [(Label n [$(Loop (t1s _> t2s) b_es)] (($$*vcs)@ ($*b_es)))]"
          "length ($$*vcs) = n"
          "length t1s = n"
  shows "((\<nexists>rvs. res = RValue rvs) \<longrightarrow> ((s,locs,es) \<Down>{(ls,r,i)} (s',locs',res))) \<and>
         (\<forall>rvs. (res = RValue rvs \<longrightarrow> (\<exists>rvs'. rvs = vcsf@rvs' \<and> ((s,locs,es) \<Down>{(ls,r,i)} (s',locs',RValue rvs')))))"
  using assms
proof (induction "(s,locs,($$*vcsf) @ es)" "(ls, r, i)" "(s',locs',res)"  arbitrary: s locs s' locs' res vcs vcsf ls es rule: reduce_to.induct)
  case (loop ves n t1s t2s m s vs es s' vs' res)
  thus ?case
    by (auto simp add: reduce_to.loop)
next
  case (const_value s vs es' s' vs' res ves)
  consider (loop) "es = ($$* vcs) @ [$Loop (t1s _> t2s) b_es]"
         | (label) "es = [Label n [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))]"
    using const_value(5)
    by blast
  thus ?case
  proof (cases)
    case loop
    thus ?thesis
      using consts_app_app_consts1[of ves es' vcsf vcs "$Loop (t1s _> t2s) b_es"]
            const_value(2,4) inj_basic_econst
      unfolding is_const_def
      apply simp
      apply safe
      apply simp_all
      apply (metis const_value.hyps(1) reduce_to_L0_consts_left)
      apply (metis const_value.hyps(2) const_value.prems(2) const_value.prems(3))
      done
  next
    case label
    thus ?thesis
      using consts_app_snoc[of "($$* ves)" es' vcsf "Label n [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))"]
            const_value(2,4) inj_basic_econst
      apply simp
      apply safe
      apply simp_all
      apply (metis (no_types, lifting) Cons_eq_map_D consts_app_ex(2) e.simps(10))
      apply (metis (no_types, lifting) const_value.prems(2) const_value.prems(3) length_map)
      done
  qed
next
  case (label_value s vs es n ls s' vs' res les)
  thus ?case
    using reduce_to.label_value
    by auto
next
  case (seq_value s vs es_e s'' vs'' res'' es' s' vs' res)
  consider (loop) "es = ($$* vcs) @ [$Loop (t1s _> t2s) b_es]"
         | (label) "es = [Label n [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))]"
    using seq_value(8)
    by blast
  thus ?case
  proof (cases)
    case loop
    thus ?thesis
      using consts_app_app_consts[of es_e es' vcsf vcs "$Loop (t1s _> t2s) b_es"]
            seq_value(2,4,5,6,7) inj_basic_econst
      unfolding is_const_def
      apply simp
      apply (metis is_const_list map_append self_append_conv)
      done
  next
    case label
    thus ?thesis
      using consts_app_snoc[of es_e es' vcsf "Label n [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))"]
            seq_value(2,4,5,6,7) inj_basic_econst
      apply simp
      apply (metis is_const_list)
      done
  qed
next
  case (seq_nonvalue1 ves s vs es_e s' vs' res)
  consider (loop) "es = ($$* vcs) @ [$Loop (t1s _> t2s) b_es]"
         | (label) "es = [Label n [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))]"
    using seq_nonvalue1(8)
    by blast
  thus ?case
  proof (cases)
    case loop
    consider
        (1) ves' ves'' where "ves = $$* ves'" "es_e = ($$* ves'') @ es" "vcsf = ves' @ ves''"
      | (2) es_1 es_2 where "ves = ($$* vcsf) @ es_1" "es_e = es_2" "es = es_1 @ es_2"
      using consts_app[OF seq_nonvalue1(7)]
      by blast
    thus ?thesis
    proof cases
      case 1
      thus ?thesis
        using seq_nonvalue1(3)[OF 1(2) seq_nonvalue1(8,9,10)] seq_nonvalue1(4)
        by auto
    next
      case 2
      thus ?thesis
        by (metis append.left_neutral consts_app_ex(2) e_type_const_conv_vs is_const_list reduce_to.seq_nonvalue1 seq_nonvalue1.hyps(1,2,4,6))
    qed
  next
    case label
    thus ?thesis
      using consts_app_snoc[of ves es_e vcsf "Label n [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))"]
            seq_nonvalue1 inj_basic_econst
      by auto
  qed
next
  case (seq_nonvalue2 s vs es_e s' vs' res es')
  consider (loop) "es = ($$* vcs) @ [$Loop (t1s _> t2s) b_es]"
         | (label) "es = [Label n [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))]"
    using seq_nonvalue2(6)
    by blast
  thus ?case
  proof (cases)
    case loop
    thus ?thesis
      using consts_app_app_consts[of es_e es' vcsf vcs "$Loop (t1s _> t2s) b_es"]
            seq_nonvalue2 inj_basic_econst
      unfolding is_const_def
      apply simp
      apply safe
          apply (metis map_append reduce_to_consts)
         apply (metis map_append reduce_to_consts)
        apply (metis reduce_to_consts)+
      done
  next
    case label
    thus ?thesis
      using consts_app_snoc[of es_e es' vcsf "Label n [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))"]
            seq_nonvalue2 inj_basic_econst
      apply simp
      apply (metis reduce_to_consts)
      done
  qed
next
  case (label_trap s vs es_l n ls s' vs' les)
  thus ?case
    using reduce_to.label_trap
    by auto
next
  case (label_break_suc s vs es n ls s' vs' bn bvs les)
  thus ?case
    using reduce_to.label_break_suc
    by auto
next
  case (label_break_nil s vs es_e n' ls s'' vs'' bvs vcs_v les s' vs' res)
  hence es_is:"n = n'"
              "es = [Label (length vcs) [$Loop (t1s _> t2s) b_es] (($$* vcs) @ ($* b_es))]"
              "es_e = ($$* vcs) @ ($* b_es)"
              "les = [$Loop (t1s _> t2s) b_es]"
              "vcs_v = vcsf"
    using consts_app_snoc[OF label_break_nil(5)[symmetric]] inj_basic_econst
    by auto
  have 1:"length bvs = n'"
    using reduce_to_break_n[OF label_break_nil(1)]
    by auto
  thus ?case
    using label_break_nil(4)[of vcs_v "($$*bvs) @ les" bvs] es_is label_break_nil(1,3,4,5,6,7,8) inj_basic_econst
          reduce_to.label_break_nil[OF label_break_nil(1), of "[]"]
    by simp fastforce
next
  case (label_return s vs es n ls s' vs' rvs les)
  thus ?case
    using reduce_to.label_return
    by auto
qed auto

lemma reduce_to_label_loop2:
  assumes "(s,locs,($$*vcsf) @ [(Label n [$(Loop (t1s _> t2s) b_es)] (vs @ ($*b_es)))]) \<Down>{(ls, r, i)} (s',locs',res)"
          "length vs = n"
          "length t1s = n"
          "const_list vs"
  shows "((\<nexists>rvs. res = RValue rvs) \<longrightarrow> ((s,locs,[(Label n [$(Loop (t1s _> t2s) b_es)] (vs @ ($*b_es)))]) \<Down>{(ls,r,i)} (s',locs',res))) \<and>
         (\<forall>rvs. (res = RValue rvs \<longrightarrow> (\<exists>rvs'. rvs = vcsf@rvs' \<and> ((s,locs,[(Label n [$(Loop (t1s _> t2s) b_es)] (vs @ ($*b_es)))]) \<Down>{(ls,r,i)} (s',locs',RValue rvs')))))"
  using reduce_to_label_loop1[OF _ _ _ assms(3)] e_type_const_conv_vs[OF assms(4)] assms(1,2)
  by blast

lemma reduce_to_n_not_break_n:
  assumes "(s,vs,es) \<Down>n{(ls,r,i)} (s',vs',res)"
          "length ls = length ls'"
          "\<forall>k < length ls. (ls!k \<noteq> ls'!k \<longrightarrow> (\<forall>rbs. res \<noteq> RBreak k rbs))"
  shows "(s,vs,es) \<Down>n{(ls',r,i)} (s',vs',res)"
  using assms
proof (induction "(s,vs,es)" n "(ls,r,i)" "(s',vs',res)" arbitrary: s vs es s' vs' ls ls' res rule: reduce_to_n.induct)
  case (br vcs n ls j s vs k)
  thus ?case
    by (metis reduce_to_n.br)
next
  case (get_local vi j s v vs k)
  thus ?case
    by (metis reduce_to_n.get_local)
next
  case (set_local vi j s v vs v' k)
  thus ?case
    by (metis reduce_to_n.set_local)
next
  case (label_value s vs es k n ls s' vs' res les)
  thus ?case
    using label_value(2)[of "n#ls'"]
    by (simp add: reduce_to_n.label_value)
next
  case (label_trap s vs es k n ls s' vs' les)
  thus ?case
    using label_trap(2)[of "n#ls'"]
    by (simp add: reduce_to_n.label_trap)
next
  case (label_break_suc s vs es k n ls s' vs' bn bvs les)
  thus ?case
    using label_break_suc(2)[of "n#ls'"]
    by simp (metis Suc_less_SucD length_Cons nth_Cons_Suc reduce_to_n.label_break_suc) 
next
  case (label_break_nil s vs es k n ls s'' vs'' bvs vcs les s' vs' res)
  show ?case
    using label_break_nil(1,3,5) label_break_nil(2)[of "n#ls'"]
    by simp (metis label_break_nil(4)[of "ls'"] gr0I label_break_nil.prems(2) nth_Cons_0 reduce_to_n.label_break_nil)
next
  case (label_return s vs es k n ls s' vs' rvs les)
  thus ?case
    by (simp add: reduce_to_n.label_return)
qed (auto intro: reduce_to_n.intros)

lemma reduce_to_n_not_return:
  assumes "(s,vs,es) \<Down>n{(ls,r,i)} (s',vs',res)"
          "(pred_option (\<lambda>r_r. r' \<noteq> Some r_r) r \<longrightarrow> (\<forall>rbs. res \<noteq> RReturn rbs))"
  shows "(s,vs,es) \<Down>n{(ls,r',i)} (s',vs',res)"
  using assms
proof (induction "(s,vs,es)" n "(ls,r,i)" "(s',vs',res)" arbitrary: s vs es s' vs' ls res rule: reduce_to_n.induct)
  case (get_local vi j s v vs k)
  thus ?case
    by (metis reduce_to_n.get_local)
next
  case (set_local vi j s v vs v' k)
  thus ?case
    by (metis reduce_to_n.set_local)
qed (auto intro: reduce_to_n.intros)

lemma reduce_to_n_not_break_n_return:
  assumes "(s,vs,es) \<Down>n{(ls,r,i)} (s',vs',res)"
          "length ls = length ls'"
          "\<forall>k < length ls. (ls!k \<noteq> ls'!k \<longrightarrow> (\<forall>rbs. res \<noteq> RBreak k rbs))"
          "(pred_option (\<lambda>r_r. r' \<noteq> Some r_r) r \<longrightarrow> (\<forall>rbs. res \<noteq> RReturn rbs))"
  shows "(s,vs,es) \<Down>n{(ls',r',i)} (s',vs',res)"
  using reduce_to_n_not_return[OF reduce_to_n_not_break_n] assms
  by blast

lemma reduce_to_n_break_n2:
  assumes "(s,vs,es) \<Down>k{(ls,r,i)} (s',vs',RBreak n vrs)"
          "length ls = length ls'"
          "(ls'!n \<le> ls!n)"
  shows "\<exists>vrs'. ((s,vs,es) \<Down>k{(ls',r,i)} (s',vs',RBreak n vrs'))"
  using assms
proof (induction "(s,vs,es)" k "(ls,r,i)" "(s',vs', RBreak n vrs)" arbitrary: s vs es s' vs' ls ls' n rule: reduce_to_n.induct)
  case (br n j ls s vs k)
  obtain vrsf vrs' where "vrs = vrsf@vrs'"
                         "ls' ! j = length vrs'"
    using br
    by (metis append_take_drop_id diff_diff_cancel length_drop)
  thus ?case
    using reduce_to_n.seq_nonvalue1[of "$$*vrsf"]
          is_const_list reduce_to_n.br[of vrs' _ j ls' s vs k r i] br.hyps(2) br.prems(1)
    by fastforce
next
  case (invoke_native cl j t1s t2s ts es ves vcs n m zs s vs k ls s' vs')
  thus ?case
    using local_value_trap
    by blast
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs')
  thus ?case
    by (metis reduce_to_n_not_break_n reduce_to_n_seq_value_all res_b.simps(5))
next
  case (label_break_suc s vs es k n ls s' vs' bn les)
  show ?case
    using label_break_suc(1,3,4) label_break_suc(2)[of "n#ls'"]
    by simp (metis reduce_to_n.label_break_suc)
next
  case (label_break_nil s vs es k n' ls s'' vs'' bvs vcs les s' vs')
  show ?case
    using label_break_nil(1,3,5,6) label_break_nil(2)[of "(n'#ls')"] label_break_nil(4)[of ls']
    by (metis (no_types, lifting) length_Cons nth_Cons_0 reduce_to_n.label_break_nil reduce_to_n_not_break_n res_b.inject(2))
qed (auto intro: reduce_to_n.intros)

lemma reduce_to_n_return2:
  assumes "(s,vs,es) \<Down>k{(ls,Some r_r,i)} (s',vs',RReturn vrs)"
          "r_r' \<le> r_r"
  shows "\<exists>vrs'. ((s,vs,es) \<Down>k{(ls,Some r_r',i)} (s',vs',RReturn vrs'))"
  using assms
proof (induction "(s,vs,es)" k "(ls,Some r_r,i)" "(s',vs',RReturn vrs)" arbitrary: s vs es s' vs' ls rule: reduce_to_n.induct)
  case (return s vs k ls)
  obtain vrsf vrs' where "vrs = vrsf@vrs'"
                         "r_r' = length vrs'"
    using return
    by (metis append_take_drop_id diff_diff_cancel length_drop)
  thus ?case
    using reduce_to_n.seq_nonvalue1[of "$$*vrsf"]
          is_const_list reduce_to_n.return[of vrs' r_r' s vs k ls i]
    by fastforce
next
  case (seq_value s vs es k s'' vs'' res'' es' s' vs')
  thus ?case
    using reduce_to_n_not_return[OF seq_value(1)] reduce_to_n.seq_value
    by blast
next
  case (label_break_nil s vs es k n ls s'' vs'' bvs vcs les s' vs')
  thus ?case
    using reduce_to_n_not_return[OF label_break_nil(1)] reduce_to_n.label_break_nil
    by blast 
qed (auto intro: reduce_to_n.intros)

(*
lemma reduce_to_label_label:
  assumes "(s,vs,($$*vcs)@[Label m les es]) \<Down>{(ls,r,i)} (s',vs',res)"
  shows "((\<nexists>rvs. res = RValue rvs) \<longrightarrow> ((s,vs,[Label m les es]) \<Down>{(ls,r,i)} (s',vs',res))) \<and>
         (\<forall>rvs. (res = RValue rvs \<longrightarrow> (\<exists>rvs'. rvs = vcs@rvs' \<and> ((s,vs,[Label m les es]) \<Down>{(ls,r,i)} (s',vs',RValue rvs')))))"
proof -
  obtain k where k_is:"(s,vs,($$*vcs)@[Label m les es]) \<Down>k{(ls,r,i)} (s',vs',res)"
    using reduce_to_imp_reduce_to_n assms
    by fastforce
  thus ?thesis
    using reduce_to_n_label[OF k_is]
    apply simp
    apply safe
    apply simp_all
    apply (simp add: reduce_to.label_trap reduce_to_n_imp_reduce_to)
    apply (simp add: reduce_to.label_return reduce_to_n_imp_reduce_to)
    apply (simp add: reduce_to.label_value reduce_to_n_imp_reduce_to)
    apply (simp add: reduce_to.label_break_suc reduce_to_n_imp_reduce_to)
    apply (metis reduce_to.label_break_nil reduce_to_n_imp_reduce_to)
    apply (metis reduce_to.label_break_nil reduce_to_n_imp_reduce_to)
    done
qed
*)
end