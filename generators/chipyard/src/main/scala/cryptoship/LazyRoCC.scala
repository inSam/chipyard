// See LICENSE.Berkeley for license details.
// See LICENSE.SiFive for license details.

//package freechips.rocketchip.tile
package chipyard.cryptoship

import chisel3._
import chisel3.util._
import chisel3.util.HasBlackBoxResource
import chisel3.experimental.IntParam

import freechips.rocketchip.tile._

import freechips.rocketchip.config._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.util.InOrderArbiter

case class RNGParams()
case object RNGKey extends Field[Option[RNGParams]](None)

case class AESParams()
case object AESKey extends Field[Option[AESParams]](None)


class rng_top(implicit p: Parameters) extends BlackBox with HasBlackBoxResource {
      val io = IO(
      	  new Bundle{val clk=Input(Clock());
	      	     val rst=Input(Reset());
		     val en_i=Input(Bool());
		     val out_random_num=Output(UInt(32.W))
	  }
      )
      addResource("/vsrc/cryptoship/rng_top.sv")
}

class RNGAccel(opcodes: OpcodeSet)(implicit p: Parameters) extends LazyRoCC(
      opcodes = opcodes, nPTWPorts = 0){
      override lazy val module = new RNGAccelImp(this) //Lazy evaluation
}

class RNGAccelImp(outer: RNGAccel)(implicit p: Parameters) extends LazyRoCCModuleImp(outer){
      val rngbb = Module(new rng_top)

      rngbb.io.clk := clock
      rngbb.io.rst := reset
      //rngbb.io.en_i := true.B

      io.cmd.ready := true.B
      io.resp.valid := RegNext(io.cmd.valid)
      io.resp.bits.rd := RegNext(io.cmd.bits.inst.rd)
      io.resp.bits.data := rngbb.io.out_random_num

      io.mem.req.valid := false.B

      io.busy := false.B
      io.interrupt := false.B
}

class WithRNG() extends Config((site, here, up) => {
      case BuildRoCC => up(BuildRoCC) ++ Seq(
      (p: Parameters) => {
      	  	      val rng = LazyModule.apply(new RNGAccel(OpcodeSet.custom1)(p))
		      rng
      	  }
      )
      case RNGKey => Some(RNGParams())
})

class AESTop(implicit p: Parameters) extends BlackBox with HasBlackBoxResource {
      val io = IO(
          new Bundle{
            val clk=Input(Clock());
            val rst=Input(Reset());
            val input_valid=Input(Bool());
            val output_ready=Input(Bool());
            val opcode=Input(UInt(7.W));
            val data_in=Input(UInt(256.W));
            val data_out=Output(UInt(128.W));
            val input_ready=Output(Bool());
            val output_valid=Output(Bool());
            val busy=Output(Bool())
          }
      )
      addResource("/vsrc/cryptoship/AESTop.v")
}

class AESAccel(opcodes: OpcodeSet)(implicit p: Parameters) extends LazyRoCC(
      opcodes = opcodes, nPTWPorts = 0){
      override lazy val module = new AESAccelImp(this) //Lazy evaluation
}

class AESAccelImp(outer: AESAccel)(implicit p: Parameters) extends LazyRoCCModuleImp(outer) {
  val aesbb = Module(new AESTop)
  val s_idle :: s_load :: s_run :: s_store:: s_done :: Nil = Enum(5)

  val cmd = Queue(io.cmd)
  val funct = cmd.bits.inst.funct
  val read_addr = Reg(UInt(40.W))
  val write_addr = Reg(UInt(40.W))
  val index = Reg(UInt(3.W))
  val req_counter = Reg(UInt(3.W))
  val resp_counter = Reg(UInt(3.W))
  val data = Reg(Vec(4, UInt(64.W)))
  val state = RegInit(s_idle)
  val output = Reg(Vec(2, UInt(64.W)))
  val op = Reg(UInt(7.W))
  val dst = Reg(UInt(5.W))
  val isKey = Reg(Bool())

  aesbb.io.output_ready := true.B
  aesbb.io.data_in := Cat(data(0), data(1), data(2), data(3))
  aesbb.io.clk := clock
  aesbb.io.rst := reset
  aesbb.io.opcode := op

  when (state === s_idle && cmd.valid) {
    state := s_load
    isKey := cmd.bits.inst.funct === 0.U
    req_counter := Mux(cmd.bits.inst.funct === 0.U, 4.U(3.W), 2.U(3.W))
    resp_counter := Mux(cmd.bits.inst.funct === 0.U, 4.U(3.W), 2.U(3.W))
    index := 0.U(3.W)
    op := cmd.bits.inst.funct
    dst := cmd.bits.inst.rd
    read_addr := cmd.bits.rs1
    write_addr := cmd.bits.rs2
    data(0) := 0.U(64.W)
    data(1) := 1.U(64.W)
    data(2) := 2.U(64.W)
    data(3) := 3.U(64.W)
  } .elsewhen (state === s_load && resp_counter === 0.U) {
    state := s_run
    aesbb.io.input_valid := true.B
  } .elsewhen (state === s_run && aesbb.io.output_valid) {
    state := Mux(isKey, s_done, s_store)
    req_counter := 2.U(3.W)
    resp_counter := 2.U(3.W)
    index:= 1.U

    output(0) := (Cat(aesbb.io.data_out(7 ,0 ), aesbb.io.data_out(15 ,8 ), aesbb.io.data_out(23 ,16 ), aesbb.io.data_out(31 ,24 ),
                      aesbb.io.data_out(39 ,32 ), aesbb.io.data_out(47 ,40 ), aesbb.io.data_out(55 ,48 ), aesbb.io.data_out(63 ,56 )))
    output(1) := (Cat(aesbb.io.data_out(71 ,64 ), aesbb.io.data_out(79 ,72 ), aesbb.io.data_out(87 ,80 ), aesbb.io.data_out(95 ,88 ),
                      aesbb.io.data_out(103 ,96 ), aesbb.io.data_out(111 ,104 ), aesbb.io.data_out(119 ,112 ), aesbb.io.data_out(127 ,120 )))
    aesbb.io.input_valid := false.B
  }.elsewhen (state === s_store && resp_counter === 0.U) {
    state := s_done
  }.elsewhen (state === s_done && io.resp.ready) {
    state := s_idle // should use RegNext
  }

  when (io.mem.req.fire() && state === s_load) {
    req_counter := req_counter - 1.U(3.W)
    read_addr := read_addr + 8.U
  }
  when (io.mem.resp.valid && state === s_store) {
    resp_counter := resp_counter - 1.U(3.W)
    req_counter := req_counter - 1.U(3.W)
    write_addr := write_addr + 8.U
    index := index - 1.U
  }

  when (io.mem.resp.valid && state === s_load) {
    data(index) := (Cat(io.mem.resp.bits.data(7 ,0 ), io.mem.resp.bits.data(15 ,8 ), io.mem.resp.bits.data(23 ,16 ), io.mem.resp.bits.data(31 ,24 ),
                        io.mem.resp.bits.data(39 ,32 ), io.mem.resp.bits.data(47 ,40 ), io.mem.resp.bits.data(55 ,48), io.mem.resp.bits.data(63 ,56 )))
    index := index + 1.U(3.W)
    resp_counter := resp_counter - 1.U(3.W)
  }


  cmd.ready := state === s_idle // command ready if in idle

  // PROC RESPONSE INTERFACE
  io.resp.valid := state === s_done // && io.resp.ready
  io.resp.bits.rd := dst
  io.resp.bits.data := 1.U // just write 1 back for fun
  io.busy := state =/= s_idle // busy when we are working
  io.interrupt := false.B

  // MEMORY REQUEST INTERFACE
  io.mem.req.valid := (state === s_load || state === s_store) && req_counter > 0.U
  io.mem.req.bits.addr := Mux(state === s_load, read_addr, write_addr)
  io.mem.req.bits.cmd := Mux(state === s_load, M_XRD, M_XWR)
  io.mem.req.bits.size := log2Ceil(8).U
  io.mem.req.bits.signed := false.B
  io.mem.req.bits.data := output(index)
  io.mem.req.bits.phys := false.B
  io.mem.req.bits.dprv := cmd.bits.status.dprv
}


// DOC include start: WithAES
class WithAES() extends Config((site, here, up) => {
  case BuildRoCC => up(BuildRoCC) ++ Seq(
    (p: Parameters) => {
      val aes = LazyModule.apply(new AESAccel(OpcodeSet.custom0)(p))
      aes
    }
  )
    case AESKey => Some(AESParams())
})
