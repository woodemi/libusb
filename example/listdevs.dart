import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi;
import 'package:convert/convert.dart';
import 'package:libusb/libusb.dart';

final DynamicLibrary Function() loadLibrary = () {
  if (Platform.isLinux) {
    return DynamicLibrary.open('${Directory.current.path}/libusb-1.0/libusb-1.0.so');
  } else if (Platform.isMacOS) {
    return DynamicLibrary.open('${Directory.current.path}/libusb-1.0/libusb-1.0.dylib');
  }
  return null;
};

final libusb = Libusb(loadLibrary());

void main(List<String> arguments) {
  var initResult = libusb.libusb_init(nullptr);
  if (initResult < 0) {
    return;
  }

  var deviceListPtr = ffi.allocate<Pointer<Pointer<libusb_device>>>();
  listdevs(deviceListPtr);
  ffi.free(deviceListPtr);

  libusb.libusb_exit(nullptr);
}

void listdevs(Pointer<Pointer<Pointer<libusb_device>>> deviceListPtr) {
  var count = libusb.libusb_get_device_list(nullptr, deviceListPtr);
  if (count < 0) {
    return;
  }

  var deviceList = deviceListPtr.value;
  printDevs(deviceList);
  libusb.libusb_free_device_list(deviceList, 1);
}

void printDevs(Pointer<Pointer<libusb_device>> deviceList) {
  var descPtr = ffi.allocate<libusb_device_descriptor>();
  var path = ffi.allocate<Uint8>(count: 8);

  for (var i = 0; deviceList[i] != nullptr; i++) {
    var dev = deviceList[i];
    var result = libusb.libusb_get_device_descriptor(dev, descPtr);
    if (result < 0) continue;

    var desc = descPtr.ref;
    var idVendor = desc.idVendor.toRadixString(16).padLeft(4, '0');
    var idProduct = desc.idProduct.toRadixString(16).padLeft(4, '0');
    var bus = libusb.libusb_get_bus_number(dev).toRadixString(16);
    var addr = libusb.libusb_get_device_address(dev).toRadixString(16);
    print('$idVendor:$idProduct (bus $bus, device $addr)');

    result = libusb.libusb_get_port_numbers(dev, path, 8);
    if (result > 0) {
      var hexList = path.asTypedList(8).map((e) => hex.encode([e]));
      print(' path: ${hexList.join('.')}');
    }
  }

  ffi.free(descPtr);
  ffi.free(path);
}
