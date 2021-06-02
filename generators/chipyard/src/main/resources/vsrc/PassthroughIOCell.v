// See LICENSE for license details

`timescale 1ns/1ps

// DO NOT USE!
module PassthroughAnalogIOCell(
    inout pad,
    inout core
);

    assign core = 1'bz;
    assign pad = core;

endmodule

// DO NOT USE!
module PassthroughDigitalGPIOCell(
    inout pad,
    output i,
    input ie,
    input o,
    input oe
);

    assign pad = oe ? o : 1'bz;
    assign i = ie ? pad : 1'b0;

endmodule

module PassthroughDigitalInIOCell(
    input pad,
    output i,
    input ie
);

    assign i = pad;

endmodule

module PassthroughDigitalOutIOCell(
    output pad,
    input o,
    input oe
);

    assign pad = o;

endmodule
