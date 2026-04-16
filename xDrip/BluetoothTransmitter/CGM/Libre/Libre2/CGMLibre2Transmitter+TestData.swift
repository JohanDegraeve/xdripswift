import Foundation

extension CGMLibre2Transmitter {
    
    struct Holder {
        static var _repeatingTimer: RepeatingTimer?
    }
    
    var repeatingTimer: RepeatingTimer? {
        get {
            return Holder._repeatingTimer
        }
        set(newValue) {
            Holder._repeatingTimer = newValue
        }
    }

    
    public func testRange() {
        
        let sensorUid = Data(hexadecimalString: "e3a18e0100a407e0")
        
        var testData = [String]()
        
        testData.append("ebb86eb952942ce055278df46b68ba1eacd3c78c7e800ea3890c61116679c2a3fcc220a95571ff760207682942f0")
        testData.append("38a5b8062dcaf18c537a7cd030cfe3e0c0c896e65131fc4ac0f51b78d496d2964f8f1971e71bca45bcd8bfcc1450")
        testData.append("5fdf6254dff6862d9b8abb82e7212a83fddc6f94d42366808b988f3fd138b7afcfe9a7a043fa899253256186992d")
        testData.append("473791584eed0ae7fc9323f466f1a04b19e45940c626422bcbe817da8f5e9097cb1806f91c8b32f802b60a098eec")
        testData.append("51e838b9189f16883f930f52893c24b95cb01bde99c49201baae2d9e7298a18efdeec1a19149638982f156f1749d")
        testData.append("2575a8743b612c83359a8bc21327202113bf606118ad6e9529b6f3803da475134e17a59010ba897a3e8615dbc154")
        testData.append("4dc1b58992ab00fff6fa550d73c3a84eda8d5b7d0e211feb7daaa92907f09062d381d59b5dab51578cebcd08ed6b")
        testData.append("dc9c3c6796ba39a3784ffb388893ffd0be96abcdba54c9f57c7c84aa310685793d36e94163cd4262b3c41ab49aa3")
        testData.append("a8f2d12975a1470bfa54584640da71b48b1249006641978f2f04fe9fc45ab2fbbfbf12011bc72b969008084b85fa")
        testData.append("bf5fefa82c8733c3abb2ed58c27479ef5453ebf819ba4e0004a2e18a3b08d68687369a2cb71cb0b0ee124ad147b4")
        testData.append("7bd91a66eb06d0f796618f4e86638d04a415c923fe641a5d44f2821f445398ed29e03b16a18134ca52fe9f6930ae")
        testData.append("a4714ad78ac51b59d79d1ffcc8c7e6f31fa5747b4bb07bb8f4d90daecf195cf8f62f34a1099a96a6f1497bbf9c17")
        testData.append("91a440bc4e3a89d24ccdef245c45f665b9531b20e35436c0ef7fb6338ccc4e90a16fc30d76aead1afb6cbb9cda39")
        testData.append("7a1b177861949ed89427b57fa12296f96244ec37ba37d286a97441ed26e6228973b5582a15e72624afd6f56ccaf5")
        testData.append("285dfbce5b6b60caee7ce7a9bd1b01384dec48c69b5ce3b74cb2341d8ba7fc18859e9cae4659bfc1d4810923e376")
        testData.append("174a92be29d2bbd720463bf0448b40a4d6b7af92960c7a616177d8fbf39cdb1a11ae703ea8d5f8829d54785885f2")
        testData.append("83ce306550dcceceb1a150891868e245dc6827eba0d39fa8a993356a58e05f352985220daebcd08dacb194cb2ac2")
        testData.append("074ff4cacdc4d20c03889cf0128ecf01f72c82af56e50f1cfbf339d2862ee3bf3df2f3d88d9dd365de1f2855669e")
        testData.append("f853959a5fda9f4db2c04a66f312b86788847e249bb129e774bf7458d8b9ed2a4101b31b1aada1f0066f42dce559")
        testData.append("8af3d125ec139f53c091d80088303a9b75711c0072423488ae8d95fa473441c944c219dc41a319a9f8df7d46368e")
        testData.append("6d16f2e78e85fb5dced880b43287491602ee6a858c2e8c7c40121018ee8a7bbf698ff84a81d9becdc450896a3cce")
        testData.append("d5c0be362d185c1231682fffdcb3d0d969379358d684c6b432d6a0bb6e9d4c7930bfecb42261ddb09cee15495402")
        testData.append("02997d100718b0c26f6beca4afbabaae09a3f2442601e2806c95fb9d5c8765779f6d7195033a7fc9cefaf65c58b8")
        testData.append("9d28120b9905f50dfe1657d6d03aa17a3812ff131f59d456d17ee722b8260dfab458a5d34ea1b876f9722bc3f68a")
        testData.append("c17402e627db6f30ddd5d80e64ae448a6bb51818a6a842cd04a8b13058fa804d020fde22f4e53cc546d9336ea9db")
        testData.append("8aa96bf9f81df2362e314344e93115fa98c3a7b00918e7ad25992f6870f1676cbb5acf4a1f05a7653c2c89f8d919")
        testData.append("caff2897dee8385df58bb91cb3144cb43baec6eebb6bbf85d712eabcfb6527c76120dfea56fedc811816832215d7")
        testData.append("225244b12ff813a57065b71920157bc44a5c6374a929b61dc62faf44089f3de3580236e2242d09ac0e0dd651878d")
        testData.append("535222705f5107f15cf91ed41357aa0b5ee1be1252b083249bfb431081d3bae2d53ef3ac09b47425e37c70c5a34b")
        testData.append("25dd0504af857da9139ab26e63de2768029de77d9859bf108174e5f5f41fa6c5c3e7d65bbcf757aabd0fca11ca63")
        testData.append("4cb41fd3a3076706ea752b8cee562d1b223578f696f22b8f168e4a140e74c0e51f639002dd72c20377ef9f4d62c6")
        testData.append("c17dc3aab3e5e60a691d008efcc72083632234aeef8d248fcc26b86634b5d6cbf629c6016ebdb9b0e707270728da")
        testData.append("6b428d5ad6b44deaaeab4bda9c7940040ddce1a8490e878815d86b1f976223589dcb13d222fbadd491310c325f2d")
        testData.append("a2cda6bca8fe9027634d3bcbc04a899c0a2e8319368240c32cc0576f05fc0dc09c0449957a899a816bf476c9e2c8")
        testData.append("f36c7d1d455d2103fb3fb64fc20f1001d7492d3df83209c8593447fe3ecf68bca2b454445ba3b8844a84c07e2bf7")
        testData.append("e45bfd2c38d0074c566351c1f2a4ad56e8ee9403f3c50fe1e5109d7096d92d9f48a5ee1ca38fa5ca3d02a215e038")
        testData.append("a7988fa4f03af3534dc200dd9f9b2034b19bf625940707602e6b1a3c1e08fbbda979041d094b0b939cb130cd7a0a")
        testData.append("f59524c4c44c1de2bb868357da57385a77d5d130d0e64c3e6c38e52a4f0fc50e1350496791cb1fdfa24348d99423")
        testData.append("b1c21b0b9cbe8743ed0b54adc48fae2501b25028ef4b7cdc1d491e6cfe871448e5cafb36dd14b0851199c9abc773")
        testData.append("96f5a3ffae210672f196aa6ba4e1a1eb294b86a2b21362dd680c28547465a3434cc92cbb833627fe0d1d4b24d95a")
        testData.append("0c6c64c1fb8e1fa5d86f43c947d93846771a11cb71e8d1abe3f4ecb099710f1d9671d42243bae20b52b23da7bf36")
        testData.append("51dd4bdd3577a5d99c5f1ddfd1e1e0a7f885240d9255b402e46c1bc37307d6ee0a4bc53742b2d4e5273bf640d440")
        testData.append("0ebf15dad4ce2541476c521fae563cdb156cd4d28ec68bd9e6adff28aa030f01855965d23bf1288b15046a139149")
        testData.append("a929ad45206fdfde397f4fff55203303ab7791427ba48e3ba80868b4f2f70dc93a1ef456af58a521367fa0f69745")
        testData.append("d7b46aad9dc3dd06b0b866a665c2cb3f489ad4e62b46e8cab80e7acf8bc0ce97d764e24bfd3f0f4785dab2f508cb")
        testData.append("6e8c726e926948cc6e549af6cf7694ac86952d73148a62511ea40179ed8a86a459ce8f40efa738b45896e67bba2b")
        testData.append("faf4a5e1d44c688e18c391e86ac2f11f6be5c9fcf27675afdd61cacf59eaf310b625047d82a92a053cbd82500802")
        testData.append("94f8029b97711513b8319c376c844198d87696ef0b0641a4f92caa12b5f1fd36c816661bb15548543989cee1d3c9")
        testData.append("9d092f56acdb51d550da81866c6a6ff67b70d2d116eead58444db02f11b83d00504197d019a361971094fd8796ec")
        testData.append("15f6d29e6985a5e99392b5c50cad9d04928421e310319266c62a8610f8fc6fd86f918d7889351ccf4dd8158fca74")
        testData.append("f719854e2bd3885f0056729fb6eba8aeb36a7468e1689cdf963f67a8d9f2964cac48e938ea1535e94bbfeffea61e")
        testData.append("cd3edf851fad2b7cd5d2195e92986056a4ff9b50b58eb57556420942cc9045c12283946d520f923bce1208904205")
        testData.append("6515456e7904f568ef08f2575d2557f2b510a89199892d7dcd4133c2bb23f5d10b2b7852eac6ab6b8b9947daa4ea")
        testData.append("d9383d19153a05fb69c944679ea868c94c86465cf25ec244d80fe0022a6ac50574aaeadd7a44599dd7a3b803a7af")
        testData.append("5f09191b89a20749762ae426bbc3a2322751fb8f4c3156dd49467bf84d101f80951632fbf345fafc427afe8bfb0f")
        testData.append("16c802a5e197d9ba1c1e84188d8edb7532f3e544c866ad69fe4c1526f10a8c732780fd943e9fddc42ef7837cf239")
        testData.append("1b52edbd4a278c7944fd9e9bebfeb6678c75b318aad4a7b2e2a69ac7f3d035014380db091a27ba2f2a534e345e28")
        testData.append("f3f5c53a9c0fc9f164f780329d08af8ad0b166718b7a9ffff6826dec536819aae249323f9c1fab5f14dedd511b33")
        testData.append("3480be1743e526dabd179ec08edb75d9f70b46602eb2f84e179ce842e1da3c77678fdc0d4173483c591361faf6c5")
        testData.append("3c405f78c7d0f9607f6da0af8adb4ed50d31143a38756ef50b67fa0383b27d627f34941a14282bfdbe022baaff37")
        testData.append("478ad9af085b08f5b75a811928cbbe0553ed13b816fb7351e4e49152022c627daede7423476d2df633d4850b6736")
        testData.append("76500449c9a0c92e7d4e4ba172d933cfef7983d534d6276fb371bbda998964a560daebd1b705e87adfc8209563c8")
        testData.append("1e6497c0d9b99468db7e34109ab94feda985d0087821dd213e25f291127dc1ff6fa6669d733c44d1dbd2f06207f9")
        testData.append("bb25641bdb0fc50523b397c51c9ef6c933b3d7dfece0c0877509db8d1a48d14e54471e528b457545c958df93a1ac")
        testData.append("c728b8fca599f3c70ebafaebb7ea0d125fd3c4db72e42da68029ec975c9c5e835961967b5f569058b5abcbffff10")
        testData.append("c5ca0441f7c08c1d4dcaf51a98cd0a53eb527eda9983d384bf60792e6d3dbb24e5c61a6a4e103659dfd029969a1c")
        testData.append("ec90df99c55f7754a2134e1876c21e5ec371bb0e7e5a460dc32fd1d7ebdb53ff6252a338ac254ee5528df4fccd9b")
        testData.append("b3a2654ff1489bd36cc50558f5469ddb6d64b7885b7804628d4dcc4b6b978c70467e1d306a4d2181240a04d38b12")
        testData.append("05a8eeba3da7056de6304d40bbc04bc84b3af919c4a7d1fd1d309c7ccec0389f6873102a3b8357d07bbaa3551653")
        testData.append("f2e8daa4eee903e905d923169cec35cd3fd319851e1a441fd740dcadcaf06a40f66146d67507dd0812130718257e")
        testData.append("08b8c69ab921660739d61cfbaa6bd01b2d244959c6cfea6fa2ce34908c90a052afd51a06cdc97954cab02621f99d")
        testData.append("9826c499f419277f1230f1840e960b379eb4ed1449ac9666cc422ca0af0dc7a894979aae164566f0fb4eca698b73")
        testData.append("b9e1aa4e93cbb519be7d3fc7f3f40a1ae750896377cae4070b4fe791ccc675c7bc0f5608141a152474260619158e")
        testData.append("970af3f82fc8416259020cb4c2da3d88c04ad88d0c9bc73aef9d8109f4575e0db0c1342fa0f82e7d5179092dc31c")
        testData.append("93e4ea50f06c2bcce107d07b8056c4720600189ee586aa9f92a9b4534e320e920563dcc231d63922e3ce85552f4d")
        testData.append("e441161b8316602bb6c300b9ab3b66628bd436db172864632e5e76ca36811dfb541abe92c313bbbdb681b55b9fd5")
        testData.append("14c10b103f511ddc65b9ebb376bcf03dc6182186e6b063fdaf483bb6e5755967a05f9de84d20e75e2a7ec1fd4abc")
        testData.append("7053d7dccd5b13684b52f4c89feb39e3c2697111553627f4fd323c5be4d6ddeaac83dfa0cb9a01db01429a682cc7")
        testData.append("d50f1fdd18d2888275005af1dbe69408acab842b5555d98bd9506dadf414c1ab84defb04d2a36cd65a5a2c9cae3e")
        testData.append("b7a1a4911528e7497e0ce79cdf9a841080008f194feab19c84ebbd9444be1f99a525433b68079eb5fafa33c03ad5")
        testData.append("44290fb231f0d412d1a1f06394b0e83e8a8a11d47d3fe71dfff410e9a878eabc14b847efe514caa9c7c64d939c00")
        testData.append("b0a4ce7d507ca2a08ee80ce3b0bf73f69a75d0427597fad46b8a296a0ffc75cde2b1181ea2d15322d5dd068d9dd4")
        testData.append("d9a6a82a1334959a9f691ec8ff836dd6cf5282a1863b9e12a5afe7fbe330be4be6768ec2ce19cd78c5950dba7e31")
        testData.append("222859b3db607a4d9cc1a87ef9acfbadaa8dea2e82e9f72e59d30bc41b441b677e15638bebbf883cc893894bc908")
        testData.append("f9bc3850c8b0be5c62eb7a21a1d94c0a60d1c75f37ed29083cae76b1840cfb230c93eb268cfb4b17885d7030eb82")
        testData.append("105796c1f5788bf2cfa62d29d5b90905891946f02fe03b03daba0f7da446b115aea51617f0c4b262dd2fe41031b9")
        testData.append("2303f59b793204562c4b7a03b7b9146178f2e3f83d3592ec26c23df30cbeddf578bd30d0d3bd4e7953f87f253e03")
        testData.append("b9d05f7f07dd7cc514b17ced643e44c52cbed608dacadaefcd22eef5d1c5f8bda631811257262e3f89b419ad655f")
        testData.append("46a4fd3005a4493cb20290c6cc1073c60c6057361e4ccc2d45a835016b860a633aac6125d064428779e7adb1b8a1")
        testData.append("15dde2e96167c096e7fe2a1f919ec18fefb28ea297a7327a11371a1a3353aa9c9d23265a878024420e952b60e4ad")
        testData.append("95ee442c5cb7a7b7dad6617e1ab0348c45b1ff029ede7eac80ef7254558ee073c5691773c69432b3c2cd13c70b61")
        testData.append("cec16e4fc1093db9d7969b697885d3ef6985e6c9600715008b2fd6fc65141a412750cbdbc5475e3ee05b7e61b9e2")
        testData.append("7077d5832fcde5644852126d3653ecadcb0a287d02a81863eddaa948f9cc838d6e08129e72aa6307782b6ccc1b54")
        testData.append("226c96099d3a4789a3c14d73fa61e0453ed7e48fba9d7e23ddad197a4a320f00923270cf9e5dfb36a8fec4ffa9ea")
        testData.append("1768bf84800eb893f6e2a2aa49d5cf66b012e66574bf98f861e434676778b6df263adb7e583c3f7b1ec330de6a51")
        testData.append("00d2e2df63028f60c668bc5559d2ea6484e99fb1fd64ee8c2d02a2d0f218c2670f266aa8d36cd9eb59e0d15b641a")
        testData.append("6c829c6f97f3b2f64c9b78f699a9113ba98582eef317aaabacce36ea636294c4bfffd032e0eeef15b2c22b8bcd20")
        testData.append("3c0f62b5ea1acdfe1601a119184b050ea97a69a76ec66c45c99942bc3755559d659ac900d6fd575fb4071498b689")
        testData.append("c6ae5f133b86432429e6c2daf7c902583a78eb09cda365d850a0f237d889734d6ce39f373d16fc397315268f3312")
        testData.append("a7323d4466ce00beb76688541ba321ab6c94eae77cf382da3e670ebbeace3b6eed3a2d4e56d515c0bddf0c71648a")
        testData.append("7afb3db6b830e8d892239eedcf39c01ac916bb07deb091aa83dbb3825c62f4dfc7c28848fdd5ac9d1552793a1a74")
        testData.append("05f6e4212ead9c0f08942543d1c1802ebd8ca2aea1f95e9f9e242c29c501287d91efffbd7021135daa4d92eb43f6")
        testData.append("af656852f0414c2ff210109fc6cb8893d7ad17157fe38e2b6cc9e0beec17ee3a71600e7c74182e16fc3cebc64a02")
        testData.append("9dfbf7bd2035e65c947eee6abb936b98ade4fe3bd740fc7ea79c098eebc6e1f5042ddb8dad4ca08b52ee1df34ffe")
        testData.append("b36aa8fa14c41e736ac1f2a69ffae7681c4b9364fedaa2e77e040f17495bcf1b34155feb201f0756bec611589930")
        testData.append("1d6a75d6e667beff4cf23bf63b04294e8a7a0b4010c1b9cf441d2b89bd12f893d79047e8eda8d420d58d04614f84")
        testData.append("5f4531d694b8646a562e0884f406944437caf3a0776fbb479d9fcd5853accfa0963980740f30d4f2036e7e4362b1")
        testData.append("c072c850c61da9d4ab368407149e991ee376fdf523707382736f4d71b585ce8f0f70920db2244aa2ce9d6448c2dd")
        testData.append("dc4dad7f06aca3badc8720b80273af32c51b372c226f172988a27c62309920af7f489bd5bd0eea11f997d7075677")
        testData.append("54f72c7360cc8f71900382ae7d362afb2dc96acc91cc6eee0e879c4f5f6782716c312fbc4728a851647539868cee")
        testData.append("81493a3431d612417b077129e57d883eb97103afab13c462efe38f0f1b7936c330ecafa961de35230ebad09383de")
        testData.append("1443ffbbbcbf2494ac19131ea2456a920f88696d311a1ada5d9def56030b37d3e53324b2ffcb0b826a0405895900")
        testData.append("ca546603dc149fc383e3c3886cccf8b027613b8b079cd7f02d62af7dfde9b508f1f9f60975c16a2aa08a0902f94a")
        testData.append("74b9cbc77c1a7c47f34912106345cc93c1d09473536930f1cb84557d9567ae25b46df6ab358d600c9c225024e940")
        testData.append("58ce1ae90942bb60576ec2ab9d3d9ba67d5ba17d43cb1e820344f7dd48aba6c1b046b6620e7206113b3e70e6a888")
        testData.append("25f081d6e529c91eb4529e0a5c0fceae1d6dc6a6b5e6dfc35c1652b6944e4d65ec4e7bc0b19fd4820bb888dc82b8")
        testData.append("5a3cd0ac03c2c17468a5fa9d07cc99345c6517ea4c513099be3b806a370ebec187d37f3d05a2dc93ce0ecb3ec35e")
        testData.append("0986fc3de00775004631b8a3fd665a4bf81242813d85e46d8eb404cbb23a0e6dad9500c94c56c1e702c8872a2679")
        testData.append("fe87d2b103d5a63b843099d8af108716f7512daef85d01cdc8512dab85419e9a35a6ca6062da917ab911da5ef377")
        testData.append("c9e2ba42b18ae53b336bea3803b887c6fb8cd5a2bb34d0c62c8112942426850f15084bdd6dd5cdda2d1d439a528f")
        testData.append("9480aa0cc6312cbd9831f4e0a64d0a0c3f64f04fc84eaffd88f3b462cc55461c85d10fbd31d15295b8416d7a3d7f")
        testData.append("b9fc1f97a70bc22e0fb54860878e27d2a618ceea867aa1e9906d53b983156f5c90b69e617e8540e7d9a019757761")
        testData.append("89a9d930a5a131c8771d3770e8cdcf841383723e01f44ee04b39bd0d1828ea5e3c6b56be4a28d3998ac5e004c3a8")
        testData.append("628ea872d55f052b4d533b9be7a3f21ad8af5a17d9df0742d9218911dedfff2851c149e107366d24d05462190256")
        testData.append("3996f55c448d9b38a051ddd6508df9655185cc0bf6701cfa50b33b0f49f4bd0fef45277b01d691e3ac6731fa90ff")
        testData.append("22f1cc97705adbf32209765261ef58ddc878b653f2f732597dedab7fbc90658ce57331e7861c7926a48c04255206")
        testData.append("3dd721735cbe17f0ba42b16ed610933ee964e24786291a5c5d72586dc503c96c27a6c5a0bd7e445d4f3094461d52")
        testData.append("f9db851886120bc832834a00fe0953ec91978e357a0ca5ff78dc4ae1ec9c1027dea655aaf3352435921d9f43c0bb")
        testData.append("a41ab6a3e54fd82a90f1c23191b4b6853b9edd0dfd7016e49b4ccdcd1fc69d41e8029e15cb34292ac145cf11e115")
        testData.append("e7e3c2ada155759646f4185cf77645b2c9373907882025106047382e5cbb85dcfe5274ec267d16a5d62d53920868")
        testData.append("0bb04dd6a2d70499185bfaeb38e6d4b6baba5829eb94c566548fea89a85279cdcd2e15439f25142bff94b6d19715")
        testData.append("0839a081425b6a52a71aceede3cbf147d2a521ce69a292b5159bce77927b3aff1c342383d311fd67eea2bed37e0b")
        testData.append("75bf58fcd5b07e249faae95d55da070e08afce4b10ba1184e503b690489ee2dba7065b7003bf0c861c57bda3988b")
        testData.append("0e2aa8bb019832b4d6a4b4a5f751b8d73794cc59e48acba85d1bc2fcd9a40b91c7a0fb6fe14d6516505afb3c77a2")
        testData.append("bbf80f41590717f4997fa0345b5458ab9815a873a5d81bfd4ec1e9262d9db23fe39dc2ab2c1fc653c46f0b081f09")
        testData.append("f927dd696580c4c626837bc94d9ba55beb9255123ca9539a888423d8301da36d686d6fdcbffe04c120b128e04926")
        testData.append("4e97c9cd338f16e24676c04b216d9e6a82a9f60cc054efaf9a3d0b494604d395822cf2644cf80c56e1e8930e251d")
        testData.append("110ec0d8a1b8c707e22d04fe816859ea3aa8fd8b8d611267ed114069bdb6b3ee98d8a8989e02a7763d6e7514a5dc")
        testData.append("f1ef70bd6f13f96d2a9d4f416712c9a5179144f7e8dc96d470e37041fa99be8d77d572ab7556366988f2b15abde0")
        testData.append("0d334300d62caf7e2c44040baa4de87562109037ba6150ecfdc3d6995d335138860b70eac4c5f5545f417c5c9148")
        testData.append("f74e2e1895e38346473af4dc5b8745c1424b7869f517763ed4a5a16aa9782be8b1f22ecb26eb64d63b96f629dff9")
        testData.append("71586b488385fdfe53ddb1bd90fb83bc70473a43d7ed1a8c1b4441e9e19abff780d59661462952c0bd174ba4568c")
        testData.append("9864a68b8b6587f5e99464f4ec12ad5c3090843d12fa521f0207063d7703f557bebf6a20038dadb26ae8b45e22e6")
        testData.append("234abb2c9552c169b987d44825197cc1f63ff76e6060a9e37232175c2083e2556fbc77302b07ba819a4fe2f8b4de")
        testData.append("4c8b2c2ec889e4b8a31defd535cadb9e31bb8fa5d36f57e98fd39573f759869df2c1d115a3303a23309317039070")
        testData.append("5cc2c0114662bff6fbafdf43495dbf4d1454980dd42aea2be3dfb2247796814d9ce666d80b78792cde6ee48f4262")
        testData.append("f1e503132e3171a5e93df0bd9d5b25e737ebd33f87fa65a13edcf5a56ce55ad4b4de5b671d7cf0667b3957d948ff")
        testData.append("bb4681d6eaada5d709df7e25404a502edef5c4b4bc056bf1377bc31c70d83dcb9876d7dffe8b5267d71c31e028ac")
        testData.append("89014100f98d1b642f1de849668570a6d34bf986178c46f0951639fa909190a314f8586469a49f9ab3fdda391d3a")
        testData.append("63fbb0aa3721a95fa6ddee9858fef274cc1cdaf97b7b60107a1b0691519843477ffa14601cb8e7627207ad4a0700")
        testData.append("24779dfac78f72442e7d1de5dbb509256705eb9075545971899544b281938f6c9974c986d21b49b5fa8a7520a499")
        testData.append("e14112f85b2b8b0a053f5988f4943367c6d6f129022f26e19a94eda11e826b470d5c2cbfd16e6d903e45314f775b")
        testData.append("20456abc5d9411a0e166ba8dab13a9f1e1316efbe71d1a701325b3839d3a1e2dc6723c254ef96bacad36773f84d9")
        testData.append("716e324f696fd3b6e17d3cbf3228dd69acb10c23757c58df072126e5ce7bb76db0fd6f340639cef423a818d723dc")
        testData.append("e430c4a86500f875670b791122f10bff253eacb5c328c6cdee37b668238264444824228e892bf520491768efe23b")
        testData.append("d1dffc48250b078d68bf57580d1edaa02c7657f4cb97bd86bfd2e34f758bac2371acbd843ecea17a13d0c92a5755")
        testData.append("843ee220917bfd3a89931ca4238f664cbb623a25a2d3d6da03adc324d6ef47228723815cdc94b667e416f00159ed")
        testData.append("91a612644046ad96ee6d6983442ae1fe7fc6482f7b5f0202aaf2daea83372bed74c8e661e38a437568ba824b8a59")
        testData.append("f40098725e409211fc0d83b8cd1c54622aec76a1acd0a37c63cd3e57fb626ef7c90e4f70ca3727301276552d59fa")
        testData.append("81889c62b1ac94ddb8cbe6ef4932d8552941a959af270386ef7ed4eaff67b02b4286d98997ea8bfc4fd897819c47")
        testData.append("ed6af06ccf4bd89cbdf406b48d68ad60c4763549c709cbb27a17b7f7e5ef72f23aea846a08bc40b4321c7005a3e1")
        testData.append("0fcb08a0fd09ba2741927e374bcedc55fe7136a8d3e08a5cebee86b277dcf8bac76909ac06d78e0161317d5beb5a")
        testData.append("6d4d7aed2dd7a32e271020670fae222635745c809c5d1c7d0b101a643cb631c74a32fefe9a9a5e7817cf09422b89")
        testData.append("abac068a5d1d88535679fbfeb85acba50cfb0b8f8e6f7036bcf1914f1e94f984ebd002d8ee1ae0212fa618790ddd")
        testData.append("4aa3a02c94c4a1e4c1cb50809ec8328f9100d6a565de2c96280e7b9b2fafd2cfd5f3f2a9c42af4f5af1762a2df61")
        testData.append("f55e47387b0e3b18afeaa95b4d7f38f6dab52b0558f7f54f288f1bccdf24991f7d950961074cd5ac058a15606311")
        testData.append("fe9e36f7ba99e1aa5df88c68cdfc34d1c054fb45dc7058162c8e53b748c1de821934fc9cbee8d5c0479accbec121")
        testData.append("2d259cc633f6f4a4f5862a1ec3a17dab2a1a583e20536b031947803ed8ffd183b802df3497758b6cebad443fb42f")
        testData.append("073b8e2e12160c6f5c882cac1fd1bde01f3f89eaac0c00e20d707619530ba69db0fed60a7cd62857887f326d4e9c")
        testData.append("1eacaa1dedfd45c9b47e40d1af9fbd082522bd4f1d305300e6367ca6f628f91691eeb81b035482bb306e04196028")
        testData.append("a3e7679cd392bfc20f0bfeb57b32dd1db4c663fd8d7b2647e35b22ca1c49c6d0078a21a9c9d763f67a457bce5479")
        testData.append("6a8580f157b2641c8c85cf94786556cead98aa04019e8fe824dfc8ee8f45c7a14d13e7b525aae4552f75d8b133a4")
        testData.append("0d00bbb86870696b342c82f0ea4bf3ddd45ef349dd73123cb365245b4d559008466aea0544db8882fbe887cdf44b")
        testData.append("a8fb54d893a95dfd34985b1f593e2c2b2ed600e196476b444c7b5b1d95131663332514f323664fa830faaad7a98b")
        testData.append("5eb419a6ab745c2fa860d87f043a87ab3c6b38fefc11ddd6c5f83aa8bab6c04468b82db35d63cadb98f2b7f41a1d")
        testData.append("13eb8d8b4b348acaad2b2e8c0bee0fbec64e629c3e62bc7c6f8cac29a0b8f4fe2d02133dc36f86ab689bbd7e70f8")
        
        var index = 0
        
        // reset previous stored values
        UserDefaults.standard.previousRawTemperatureValues = nil
        UserDefaults.standard.previousTemperatureAdjustmentValues = nil
        UserDefaults.standard.previousRawGlucoseValues = nil
        
        // if true, then values wil be skipped, amount of skipped values increased all the time,
        let skipValues = false
        
        var skip = 0
        var skipped = 0
        
        repeatingTimer = RepeatingTimer(timeInterval: 60.0, eventHandler: {
            
            if skipped < skip && skipValues {
                //skip one
                skipped = skipped + 1
                
            } else {

                if let data = Data(hexadecimalString: testData[index]), let sensorUid = sensorUid, index < testData.count {
                    
                    DispatchQueue.main.sync {
                        self.processValue(value: data, sensorUID: sensorUid)
                    }
                    
                }
                
                skip = skip + 1
                skipped = 0

            }
            
            index = index + 1
            
        })
        
        if let repeatingTimer = repeatingTimer {
            repeatingTimer.resume()
        }
        
    }
}
