/* Copyright (C) 2003-2013 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include <sysdep.h>
#include <lowlevellock.h>
#include <lowlevelrwlock.h>
#include <pthread-errnos.h>
#include <tcb-offsets.h>
#include <kernel-features.h>
#include "lowlevel-atomic.h"


	.text

	.globl	pthread_rwlock_timedrdlock
	.type	pthread_rwlock_timedrdlock,@function
	.align	5
	cfi_startproc
pthread_rwlock_timedrdlock:
	mov.l	r12, @-r15
	cfi_adjust_cfa_offset (4)
	cfi_rel_offset (r12, 0)
	mov.l	r10, @-r15
	cfi_adjust_cfa_offset (4)
	cfi_rel_offset (r10, 0)
	mov.l	r9, @-r15
	cfi_adjust_cfa_offset (4)
	cfi_rel_offset (r9, 0)
	mov.l	r8, @-r15
	cfi_adjust_cfa_offset (4)
	cfi_rel_offset (r8, 0)
	sts.l	pr, @-r15
	cfi_adjust_cfa_offset (4)
	cfi_rel_offset (pr, 0)
	add	#-8, r15
	cfi_adjust_cfa_offset (8)
	mov	r4, r8
	mov	r5, r9

	/* Get the lock.  */
	mov	#0, r3
	mov	#1, r4
#if MUTEX == 0
	CMPXCHG (r3, @r8, r4, r2)
#else
	CMPXCHG (r3, @(MUTEX,r8), r4, r2)
#endif
	bf	1f
2:
	mov.l	@(WRITER,r8), r0
	tst	r0, r0
	bf	14f
	mov.l	@(WRITERS_QUEUED,r8), r0
	tst	r0, r0
	bt	5f
	mov	#FLAGS, r0
	mov.b	@(r0,r8), r0
	tst	r0, r0
	bt	5f
3:
	/* Check the value of the timeout parameter.  */
	mov.l	.L1g0, r1
	mov.l	@(4,r9), r0
	cmp/hs	r1, r0
	bt	19f

	mov.l	@(READERS_QUEUED,r8), r0
	add	#1, r0
	mov.l	r0, @(READERS_QUEUED,r8)
	tst	r0, r0
	bt	4f

	mov.l	@(READERS_WAKEUP,r8), r10

#if MUTEX == 0
	DEC (@r8, r2)
#else
	DEC (@(MUTEX,r8), r2)
#endif
	tst	r2, r2
	bf	10f

11:
	/* Get current time.  */
	mov	r15, r4
	mov	#0, r5
	mov	#__NR_gettimeofday, r3
	trapa	#0x12
	SYSCALL_INST_PAD

	mov.l	@(4,r15), r0
	mov.w	.L1k0, r1
	dmulu.l	r0, r1		/* Milli seconds to nano seconds.  */
	mov.l	@r9, r2
	mov.l	@(4,r9), r3
	mov.l	@r15, r0
	sts	macl, r1
	sub	r0, r2
	clrt
	subc	r1, r3
	bf	15f
	mov.l	.L1g0, r1
	add	r1, r3
	add	#-1, r2
15:
	cmp/pz	r2
	bf	16f		/* Time is already up.  */

	/* Store relative timeout.  */
	mov.l	r2, @r15
	mov.l	r3, @(4,r15)

	/* Futex call.  */
	mov	r15, r7
#ifdef __ASSUME_PRIVATE_FUTEX
	mov	#PSHARED, r0
	mov.b	@(r0,r8), r5
	mov	#(FUTEX_PRIVATE_FLAG|FUTEX_WAIT), r0
	xor	r0, r5
	extu.b	r5, r5
#else
	mov	#PSHARED, r0
	mov.b	@(r0,r8), r5
	extu.b	r5, r5
# if FUTEX_WAIT != 0
	mov	#FUTEX_WAIT, r0
	or	r0, r5
# endif
	stc	gbr, r1
	mov.w	.Lpfoff, r2
	add	r2, r1
	mov.l	@r1, r0
	xor	r0, r5
#endif
	mov	r10, r6
	mov	r8, r4
	add	#READERS_WAKEUP, r4
	mov	#SYS_futex, r3
	extu.b	r3, r3
	trapa	#0x14
	SYSCALL_INST_PAD
	mov	r0, r3

17:
	/* Reget the lock.  */
	mov	#0, r5
	mov	#1, r4
#if MUTEX == 0
	CMPXCHG (r5, @r8, r4, r2)
#else
	CMPXCHG (r5, @(MUTEX,r8), r4, r2)
#endif
	bf	12f

13:
	mov.l	@(READERS_QUEUED,r8), r0
	add	#-1, r0
	mov.l	r0, @(READERS_QUEUED,r8)
	mov	#-ETIMEDOUT, r0
	cmp/eq	r0, r3
	bf	2b

18:
	bra	9f
	 mov	#ETIMEDOUT, r3

5:
	mov	#0, r3
	mov.l	@(NR_READERS,r8), r0
	add	#1, r0
	mov.l	r0, @(NR_READERS,r8)
	tst	r0, r0
	bt	8f

9:
#if MUTEX == 0
	DEC (@r8, r2)
#else
	DEC (@(MUTEX,r8), r2)
#endif
	tst	r2, r2
	bf	6f
7:
	cfi_remember_state
	add	#8,r15
	cfi_adjust_cfa_offset (-8)
	lds.l	@r15+, pr
	cfi_adjust_cfa_offset (-4)
	cfi_restore (pr)
	mov.l	@r15+, r8
	cfi_adjust_cfa_offset (-4)
	cfi_restore (r8)
	mov.l	@r15+, r9
	cfi_adjust_cfa_offset (-4)
	cfi_restore (r9)
	mov.l	@r15+, r10
	cfi_adjust_cfa_offset (-4)
	cfi_restore (r10)
	mov.l	@r15+, r12
	cfi_adjust_cfa_offset (-4)
	cfi_restore (r12)
	rts
	 mov	r3, r0
	cfi_restore_state

#ifndef __ASSUME_PRIVATE_FUTEX
.Lpfoff:
	.word	PRIVATE_FUTEX - TLS_PRE_TCB_SIZE
#endif
	.align	2
.L1k0:
	.long	1000
.L1g0:
	.long	1000000000

1:
	mov	r8, r5
#if MUTEX != 0
	add	#MUTEX, r5
#endif
	mov	#PSHARED, r0
	mov.b	@(r0,r8), r6
	extu.b	r6, r6
	mov.l	.Lwait2, r1
	bsrf	r1
	 mov	r2, r4
.Lwait2b:
	bra	2b
	 nop
14:
	stc	gbr, r1
	mov.w	.Ltidoff, r2
	add	r2, r1
	mov.l	@r1, r1
	cmp/eq	r1, r0
	bf	3b
	/* Deadlock detected.  */
	bra	9b
	 mov	#EDEADLK, r3

.Ltidoff:
	.word	TID - TLS_PRE_TCB_SIZE

6:
	mov	r3, r10
	mov	r8, r4
#if MUTEX != 0
	add	#MUTEX, r4
#endif
	mov	#PSHARED, r0
	mov.b	@(r0,r8), r5
	extu.b	r5, r5
	mov.l	.Lwake2, r1
	bsrf	r1
	 nop
.Lwake2b:
	bra	7b
	 mov	r10, r3

8:
	/* Overflow.  */
	mov.l	@(NR_READERS,r8), r1
	add	#-1, r1
	mov.l	r1, @(NR_READERS,r8)
	bra	9b
	 mov	#EAGAIN, r3

4:
	/* Overflow.  */
	mov.l	@(READERS_QUEUED,r8), r1
	add	#-1, r1
	mov.l	r1, @(READERS_QUEUED,r8)
	bra	9b
	 mov	#EAGAIN, r3

10:
	mov	r8, r4
#if MUTEX != 0
	add	#MUTEX, r4
#endif
	mov	#PSHARED, r0
	mov.b	@(r0,r8), r5
	extu.b	r5, r5
	mov.l	.Lwake3, r1
	bsrf	r1
	 nop
.Lwake3b:
	bra	11b
	 nop

12:
	mov	r3, r10
	mov	r8, r5
#if MUTEX != 0
	add	#MUTEX, r5
#endif
	mov	#PSHARED, r0
	mov.b	@(r0,r8), r6
	extu.b	r6, r6
	mov.l	.Lwait3, r1
	bsrf	r1
	 mov	r2, r4
.Lwait3b:
	bra	13b
	 mov	r10, r3

16:
	bra	17b
	 mov	#-ETIMEDOUT, r3

19:
	bra	9b
	 mov	#EINVAL, r3
	cfi_endproc

	.align	2
.Lwait2:
	.long	__lll_lock_wait-.Lwait2b
.Lwake2:
	.long	__lll_unlock_wake-.Lwake2b
.Lwait3:
	.long	__lll_lock_wait-.Lwait3b
.Lwake3:
	.long	__lll_unlock_wake-.Lwake3b
	.size	pthread_rwlock_timedrdlock,.-pthread_rwlock_timedrdlock
