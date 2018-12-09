subfolder classes defines all datamodels with methods to store data in the persistent store.

extensions are created by xcode "Editor", "create NSManagedObject Subclass"

Not all classes have an extension, example BluetoothDevice, probably doesn't need to be stored in the datamodel, because there will only be one
with just a few attribures, maybe better to store in the settings