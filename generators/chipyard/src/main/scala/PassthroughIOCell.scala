package chipyard.iobinders

import chisel3._
import chisel3.util.{Cat, HasBlackBoxResource}
import chisel3.experimental.{Analog, DataMirror, IO}
import barstools.iocell.chisel._


abstract class PassthroughIOCell extends BlackBox with HasBlackBoxResource {
  addResource("/vsrc/PassthroughIOCell.v")
}

class PassthroughAnalogIOCell extends PassthroughIOCell with AnalogIOCell {
  val io = IO(new AnalogIOCellBundle)
}
class PassthroughDigitalGPIOCell extends PassthroughIOCell with DigitalGPIOCell {
  val io = IO(new DigitalGPIOCellBundle)
}
class PassthroughDigitalInIOCell extends PassthroughIOCell with DigitalInIOCell {
  val io = IO(new DigitalInIOCellBundle)
}
class PassthroughDigitalOutIOCell extends PassthroughIOCell with DigitalOutIOCell {
  val io = IO(new DigitalOutIOCellBundle)
}

case class PassthroughIOCellParams() extends IOCellTypeParams {
  def analog() = Module(new PassthroughAnalogIOCell)
  def gpio() = Module(new PassthroughDigitalGPIOCell)
  def input() = Module(new PassthroughDigitalInIOCell)
  def output() = Module(new PassthroughDigitalOutIOCell)
}
