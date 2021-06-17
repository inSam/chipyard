package chipyard.example

import chisel3._
import chisel3.util._
import chisel3.experimental.{IO}
import freechips.rocketchip.config.{Parameters, Field}
import chisel3.core.{IntParam, Reset}
import freechips.rocketchip.subsystem.{BaseSubsystem}
import freechips.rocketchip.regmapper.{HasRegMap, RegField}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._
import freechips.rocketchip.tilelink._


case class CustomGPIOParams(
    address: BigInt,
    nInput: Int,
    nOutput: Int,
)

case object CustomGPIOKey extends Field[Option[CustomGPIOParams]](None)

class CustomGPIOIO(params: CustomGPIOParams) extends Bundle{
    val input_pins = Input(UInt(params.nInput.W))
    val output_pins = Output(UInt(params.nOutput.W))

    override def cloneType = (new CustomGPIOIO(params)).asInstanceOf[this.type]
}

class CustomGPIO(params: CustomGPIOParams)(implicit p: Parameters) extends LazyModule {
    val device = new SimpleDevice("custom-gpio", Seq("ee272b,gpio"))
    val node = TLRegisterNode(
        address = Seq(AddressSet(params.address, 0xFFFF)),
        device = device,
        beatBytes = 8,
        concurrency = 1)

    lazy val module = new LazyModuleImp(this) {
        val io = IO(new Bundle{
            val pins = new CustomGPIOIO(params)
        })
        
        val inputReg = Reg(UInt(params.nInput.W))
        val outputReg = Reg(UInt(params.nOutput.W))

        inputReg := io.pins.input_pins
        io.pins.output_pins := outputReg

        node.regmap(
            0x0 -> Seq(RegField.r(64, inputReg)),
            0x8 -> Seq(RegField(64, outputReg))
        )
    }
}

trait CanHaveCustomGPIO { this: BaseSubsystem =>
   
   val customGPIOOpt = p(CustomGPIOKey).map { params =>
        val custom_gpio = LazyModule(new CustomGPIO(params)) 
        pbus.toVariableWidthSlave(Some("pins")) {custom_gpio.node } 

        val customGPIOIO = InModuleBody {
            val customGPIOIO = IO(new CustomGPIOIO(params)).suggestName("custom_gpio")
            customGPIOIO <> custom_gpio.module.io.pins
            customGPIOIO
        }
        customGPIOIO
   }
}

// trait CanHaveCustomGPIOModuleImp extends LazyModuleImp {
//     val outer: CanHaveCustomGPIO

//     val custom_gpio = outer.custom_gpio match {
//         case Some(custom_gpio) => {
//             val custom_gpio_io = IO(new CustomGPIOIO(outer.gpio_params))
//             custom_gpio_io <> outer.custom_gpio.get.module.io.pins
//             Some(custom_gpio_io)
//         }
//         case None => None
//     }
// }
