local _menu_width = 1100
local _inner_menu_width = 800
local _menu_height = 600

local world_map_overlay = {}

local deathlog_tabcontainer = nil

local class_tbl = {
	["Warrior"] = 1,
	["Paladin"] = 2,
	["Hunter"] = 3,
	["Rogue"] = 4,
	["Priest"] = 5,
	["Shaman"] = 7,
	["Mage"] = 8,
	["Warlock"] = 9,
	["Druid"] = 11,
}

local race_tbl = {
	["Human"] = 1,
	["Orc"] = 2,
	["Dwarf"] = 3,
	["Night Elf"] = 4,
	["Undead"] = 5,
	["Tauren"] = 6,
	["Gnome"] = 7,
	["Troll"] = 8,
}

local zone_tbl = {
	["Durotar"] = 1411,
	["Mulgore"] = 1412,
	["The Barrens"] = 1413,
	["Kalimdor"] = 1414,
	["Eastern Kingdoms"] = 1415,
	["Alterac Mountains"] = 1416,
	["Arathi Highlands"] = 1417,
	["Badlands"] = 1418,
	["Blasted Lands"] = 1419,
	["Tirisfal Glades"] = 1420,
	["Silverpine Forest"] = 1421,
	["Western Plaguelands"] = 1422,
	["Eastern Plaguelands"] = 1423,
	["Hillsbrad Foothills"] = 1424,
	["The Hinterlands"] = 1425,
	["Dun Morogh"] = 1426,
	["Searing Gorge"] = 1427,
	["Burning Steppes"] = 1428,
	["Elwynn Forest"] = 1429,
	["Deadwind Pass"] = 1430,
	["Duskwood"] = 1431,
	["Loch Modan"] = 1432,
	["Redridge Mountains"] = 1433,
	["Stranglethorn Vale"] = 1434,
	["Swamp of Sorrows"] = 1435,
	["Westfall"] = 1436,
	["Wetlands"] = 1437,
	["Teldrassil"] = 1438,
	["Darkshore"] = 1439,
	["Ashenvale"] = 1440,
	["Thousand Needles"] = 1441,
	["Stonetalon Mountains"] = 1442,
	["Desolace"] = 1443,
	["Feralas"] = 1444,
	["Dustwallow Marsh"] = 1445,
	["Tanaris"] = 1446,
	["Azshara"] = 1447,
	["Felwood"] = 1448,
	["Un'Goro Crater"] = 1449,
	["Moonglade"] = 1450,
	["Silithus"] = 1451,
	["Winterspring"] = 1452,
}
local overlay_info = {
	--[[1411: Durotar]]
	[1411] = {
		["128:110:464:33"] = "271427",
		["160:120:413:476"] = "2212659",
		["160:190:474:384"] = "271426",
		["190:180:462:286"] = "271440",
		["190:200:327:60"] = "271439",
		["200:240:549:427"] = "271437",
		["210:160:427:78"] = "271428",
		["215:215:355:320"] = "271443",
		["220:230:432:170"] = "271421",
		["230:230:301:189"] = "271422",
		["445:160:244:0"] = "271435, 271442",
	},
	--[[1412: Mulgore]]
	[1412] = {
		["128:120:473:260"] = "272185",
		["128:155:379:242"] = "272178",
		["128:205:303:307"] = "272176",
		["170:128:458:369"] = "272180",
		["185:128:291:0"] = "272172",
		["205:128:395:0"] = "272179",
		["205:230:502:16"] = "272169",
		["210:180:255:214"] = "272181",
		["215:240:428:80"] = "272177",
		["225:235:532:238"] = "272186",
		["256:190:523:356"] = "272170",
		["256:200:367:303"] = "272173",
		["280:240:249:59"] = "272187, 272171",
		["470:243:270:425"] = "272168, 272165",
	},
	--[[1413: The Barrens]]
	[1413] = {
		["100:165:564:52"] = "270569",
		["115:110:507:294"] = "852702",
		["120:110:555:0"] = "270553",
		["120:125:384:115"] = "270560",
		["125:115:492:63"] = "270584",
		["125:125:556:189"] = "270585",
		["125:165:442:298"] = "852696",
		["128:100:412:0"] = "852705",
		["128:105:419:63"] = "270554",
		["128:128:306:130"] = "852699",
		["128:128:341:537"] = "852704",
		["128:128:431:479"] = "852694",
		["140:128:498:119"] = "270574",
		["145:125:365:350"] = "852697",
		["150:120:527:307"] = "852701",
		["155:115:407:553"] = "852703",
		["155:128:335:462"] = "852695",
		["155:128:481:211"] = "270565",
		["155:155:431:118"] = "270559",
		["170:120:456:0"] = "270564",
		["175:185:365:177"] = "852700",
		["200:145:317:29"] = "270572",
		["200:185:340:234"] = "852693",
		["210:150:355:402"] = "852698",
		["95:100:581:247"] = "270573",
	},

	--[[1416: Alterac Mountains]]
	[1416] = {
		["160:175:225:478"] = "768731",
		["165:197:314:471"] = "768752",
		["190:170:317:372"] = "768732",
		["195:288:399:380"] = "768721, 768722",
		["200:200:406:279"] = "768730",
		["220:280:196:131"] = "768738, 769205",
		["235:200:462:77"] = "768753",
		["255:255:270:197"] = "768739",
		["255:320:462:307"] = "768744, 768745",
		["280:240:334:162"] = "768723, 769200",
		["285:230:276:0"] = "768728, 768729",
		["300:300:26:262"] = "769201, 769202, 769203, 769204",
		["330:265:44:403"] = "768734, 768735, 768736, 768737",
		["350:370:626:253"] = "768717, 768718, 768719, 768720",
		["370:300:549:105"] = "768748, 768749, 768750, 768751",
	},
	--[[1417: Arathi Highlands]]
	[1417] = {
		["160:230:558:112"] = "270360",
		["170:155:419:293"] = "2212546",
		["175:225:370:186"] = "270352",
		["180:210:472:165"] = "270350",
		["190:210:138:54"] = "270347",
		["190:240:87:138"] = "2212539",
		["200:220:355:412"] = "270348",
		["205:250:655:120"] = "270336",
		["210:185:286:310"] = "270346",
		["215:210:559:333"] = "270353",
		["215:235:432:362"] = "270342",
		["230:195:531:276"] = "270343",
		["230:240:192:90"] = "270351",
		["240:230:108:287"] = "270358",
		["245:245:232:145"] = "270349",
		["256:215:171:424"] = "270361",
	},
	--[[1418: Badlands]]
	[1418] = {
		["195:200:325:148"] = "270543",
		["200:195:445:120"] = "270532",
		["220:220:551:48"] = "270530",
		["230:230:349:256"] = "2212608",
		["240:255:0:148"] = "2212593",
		["245:205:389:7"] = "2212606",
		["245:205:498:209"] = "2212592",
		["255:205:17:310"] = "270529",
		["255:220:12:428"] = "270520",
		["255:280:501:341"] = "270540, 270527",
		["265:270:345:389"] = "270522, 270550, 270528, 270536",
		["270:275:159:199"] = "270525, 270521, 2212603, 2212605",
		["285:240:148:384"] = "2212599, 2212601",
		["370:455:611:110"] = "270534, 270551, 270546, 270535",
	},
	--[[1419: Blasted Lands]]
	[1419] = {
		["170:145:405:123"] = "391431",
		["170:200:472:9"] = "391433",
		["185:155:310:133"] = "391425",
		["185:190:559:30"] = "391432",
		["195:180:361:15"] = "391435",
		["225:170:501:140"] = "391430",
		["245:195:361:195"] = "391434",
		["265:220:453:259"] = "391437, 391436",
		["384:450:212:178"] = "391429, 391428, 391427, 391426",
	},
	--[[1420: Tirisfal Glades]]
	[1420] = {
		["128:158:537:299"] = "273015",
		["150:128:474:327"] = "273016",
		["173:128:694:289"] = "273000",
		["174:220:497:145"] = "273020",
		["175:247:689:104"] = "272996",
		["186:128:395:277"] = "2213434",
		["201:288:587:139"] = "273009, 273002",
		["211:189:746:125"] = "2213425",
		["216:179:630:326"] = "273006",
		["230:205:698:362"] = "2213418",
		["237:214:757:205"] = "272999",
		["243:199:363:349"] = "273003",
		["245:205:227:328"] = "273001",
		["256:156:239:250"] = "273017",
		["256:210:335:139"] = "273019",
		["315:235:463:361"] = "2213428, 2213430",
	},
	--[[1421: Silverpine Forest]]
	[1421] = {
		["140:125:391:446"] = "2213067",
		["160:170:470:261"] = "272598",
		["165:185:382:252"] = "272616",
		["175:165:402:65"] = "2213080",
		["180:128:323:128"] = "2213065",
		["180:185:457:144"] = "2213082",
		["185:165:286:37"] = "272610",
		["210:160:352:168"] = "272620",
		["210:215:379:447"] = "272609",
		["220:160:364:359"] = "272613",
		["240:180:491:417"] = "272599",
		["240:240:494:262"] = "272614",
		["250:215:593:74"] = "272600",
		["256:160:465:0"] = "2213063",
		["256:220:459:13"] = "2213084",
	},
	--[[1422: Western Plaguelands]]
	[1422] = {
		["160:125:300:311"] = "273113",
		["160:200:566:198"] = "273121",
		["170:165:600:412"] = "273107",
		["170:190:451:323"] = "273102",
		["180:205:520:250"] = "273094",
		["205:340:590:86"] = "273122, 273103",
		["220:150:381:265"] = "2212523",
		["220:180:382:164"] = "273114",
		["225:185:137:293"] = "273120",
		["285:230:260:355"] = "2212522, 2212521",
		["300:206:355:462"] = "273108, 273101",
		["340:288:307:16"] = "273095, 273111, 273100, 273090",
		["370:270:504:343"] = "273119, 273092, 273112, 273093",
	},
	--[[1423: Eastern Plaguelands]]
	[1423] = {
		["165:160:537:367"] = "271544",
		["175:245:716:299"] = "271533",
		["180:160:592:241"] = "271542",
		["185:150:172:477"] = "271512",
		["190:205:620:128"] = "271520",
		["190:205:79:98"] = "271522",
		["195:275:620:291"] = "271543, 271530",
		["200:205:156:360"] = "271551",
		["205:165:291:401"] = "271548",
		["205:165:614:30"] = "271554",
		["205:250:409:345"] = "2212700",
		["210:179:309:489"] = "271514",
		["210:210:271:261"] = "271536",
		["220:360:7:231"] = "2212705, 2212706",
		["225:215:722:166"] = "271537",
		["230:150:422:36"] = "271535",
		["230:235:442:199"] = "271523",
		["240:195:457:109"] = "271521",
		["240:200:194:9"] = "271529",
		["245:170:717:471"] = "271553",
		["250:175:537:463"] = "271532",
		["360:270:169:83"] = "271518, 271527, 2212703, 2212704",
	},
	--[[1424: Hillsbrad Foothills]]
	[1424] = {
		["125:100:109:482"] = "271904",
		["165:200:175:275"] = "2212736",
		["205:155:414:154"] = "271897",
		["215:240:541:236"] = "2212742",
		["220:310:509:0"] = "271894, 2212744",
		["230:320:524:339"] = "2212737, 2212738",
		["235:270:418:201"] = "271905, 2212743",
		["240:275:637:294"] = "271885, 271877",
		["285:155:208:368"] = "2212746, 2212747",
		["288:225:2:192"] = "271876, 271881",
		["305:275:198:155"] = "271883, 271892, 2212739, 2212740",
		["384:365:605:75"] = "271872, 271898, 271882, 271891",
	},
	--[[1425: The Hinterlands]]
	[1425] = {
		["145:220:158:149"] = "271927",
		["160:145:512:232"] = "271933",
		["170:170:319:302"] = "271934",
		["170:310:693:303"] = "271938, 271916",
		["180:170:408:260"] = "271929",
		["185:195:237:185"] = "271928",
		["195:185:240:387"] = "271937",
		["200:165:373:365"] = "271922",
		["205:195:374:164"] = "271910",
		["225:200:171:306"] = "770218",
		["235:285:505:333"] = "271912, 271920",
		["255:205:13:245"] = "271917",
		["275:275:509:19"] = "271908, 271935, 271936, 271909",
		["280:205:571:239"] = "271915, 271921",
	},
	--[[1426: Dun Morogh]]
	[1426] = {
		["115:115:252:249"] = "2212640",
		["125:125:217:287"] = "271398",
		["128:120:792:279"] = "2212654",
		["128:128:573:280"] = "271389",
		["128:165:502:221"] = "2212651",
		["128:165:759:173"] = "2212653",
		["128:180:281:167"] = "271392",
		["128:190:347:163"] = "271418",
		["150:128:295:385"] = "271406",
		["155:128:522:322"] = "271401",
		["155:170:694:273"] = "271409",
		["165:165:608:291"] = "271408",
		["180:128:274:296"] = "2212641",
		["180:165:166:184"] = "2212644",
		["200:185:314:311"] = "271400",
		["200:200:386:294"] = "271417",
		["240:185:155:403"] = "2212639",
		["315:200:397:163"] = "271410, 271396",
	},
	--[[1427: Searing Gorge]]
	[1427] = {
		["275:235:77:366"] = "254503, 254504",
		["305:220:494:300"] = "2201968, 2201949",
		["305:230:545:407"] = "254527, 254528",
		["360:280:247:388"] = "2201972, 2201970, 2201969, 2201971",
		["405:430:85:30"] = "254509, 254510, 254511, 254512",
		["425:325:250:170"] = "254529, 254530, 254531, 254532",
		["460:365:422:8"] = "254505, 254506, 254507, 254508",
	},
	--[[1428: Burning Steppes]]
	[1428] = {
		["220:225:707:168"] = "270927",
		["225:220:36:109"] = "270938",
		["245:265:334:114"] = "270912, 270909",
		["256:280:173:101"] = "270919, 270911",
		["270:285:513:99"] = "270922, 270934, 270923, 270937",
		["270:310:589:279"] = "270920, 270914, 270908, 270929",
		["280:355:722:46"] = "270944, 270910, 270935, 270945",
		["294:270:708:311"] = "270906, 270918, 270936, 270942",
		["320:270:377:285"] = "270933, 270943, 270921, 270928",
		["415:315:56:258"] = "270941, 270925, 270926, 270917",
	},
	--[[1429: Elwynn Forest]]
	[1429] = {
		["225:220:422:332"] = "271560",
		["240:220:250:270"] = "271567",
		["255:250:551:292"] = "271573",
		["256:210:704:330"] = "271578",
		["256:237:425:431"] = "271582",
		["256:240:238:428"] = "271576",
		["256:249:577:419"] = "271559",
		["256:256:381:147"] = "271572",
		["256:341:124:327"] = "2212708, 2212709",
		["306:233:696:435"] = "271557, 271583",
		["310:256:587:190"] = "271584, 271565",
		["485:405:0:0"] = "2212713, 2212714, 2212715, 2212716",
	},
	--[[1430: Deadwind Pass]]
	[1430] = {
		["270:270:426:299"] = "271092, 271085, 271086, 271089",
		["300:245:269:337"] = "271095, 271079",
		["380:365:249:76"] = "271075, 271076, 271080, 271081",
	},
	--[[1431: Duskwood]]
	[1431] = {
		["160:330:19:132"] = "271453, 271454",
		["195:145:102:302"] = "2212669",
		["200:175:653:120"] = "271466",
		["220:220:690:353"] = "2212676",
		["220:340:504:117"] = "271470, 271477",
		["235:250:390:382"] = "271449",
		["250:230:539:369"] = "271455",
		["255:285:243:348"] = "271448, 271456",
		["275:250:55:342"] = "271444, 271483",
		["315:280:631:162"] = "271471, 271461, 271450, 271451",
		["350:300:85:149"] = "271473, 271463, 271467, 271464",
		["360:420:298:79"] = "2212678, 2212679, 2212680, 2212681",
		["910:210:89:31"] = "271481, 271460, 271474, 271468",
	},
	--[[1432: Loch Modan]]
	[1432] = {
		["195:250:109:370"] = "252899",
		["230:300:125:12"] = "252882, 252883",
		["235:270:229:11"] = "252884, 2212852",
		["255:285:215:348"] = "252886, 252887",
		["256:230:217:203"] = "252898",
		["290:175:339:11"] = "2212855, 2212856",
		["295:358:309:310"] = "252862, 252863, 2212828, 2212829",
		["315:235:542:48"] = "252880, 252881",
		["320:410:352:87"] = "252894, 252895, 252896, 252897",
		["345:256:482:321"] = "252866, 252867",
		["370:295:546:199"] = "252890, 252891, 252892, 252893",
	},
	--[[1433: Redridge Mountains]]
	[1433] = {
		["235:270:399:129"] = "272334, 2212936",
		["250:250:654:161"] = "272372",
		["255:300:500:215"] = "2212977, 2212978",
		["275:256:277:0"] = "272357, 272342",
		["320:210:595:320"] = "272347, 272371",
		["340:195:83:197"] = "272351, 272340",
		["365:245:121:72"] = "272362, 272356",
		["365:350:0:284"] = "272364, 272348, 272358, 272359",
		["430:290:187:333"] = "272344, 272354, 272350, 272339",
		["465:255:484:361"] = "272369, 272363",
		["535:275:133:240"] = "272335, 272343, 2212940, 2212942, 2212943, 2212945",
	},
	--[[1434: Stranglethorn Vale]]
	[1434] = {
		["105:110:311:131"] = "2213161",
		["105:125:387:64"] = "2213191",
		["110:105:260:132"] = "2213150",
		["110:110:306:301"] = "2213171",
		["110:140:371:129"] = "2213145",
		["115:115:156:42"] = "2213197",
		["120:120:345:276"] = "2213148",
		["125:120:314:493"] = "2213152",
		["125:125:280:368"] = "2213159",
		["125:140:196:3"] = "2213173",
		["128:125:331:59"] = "2213158",
		["128:125:364:231"] = "2213194",
		["128:175:432:94"] = "2213162",
		["140:110:269:26"] = "2213165",
		["145:128:203:433"] = "2213147",
		["155:150:388:0"] = "2213156",
		["165:175:194:284"] = "2213146",
		["165:190:229:422"] = "2213192",
		["170:125:394:212"] = "2213174",
		["170:90:284:0"] = "2213168",
		["190:175:152:90"] = "2213188",
		["200:185:235:189"] = "2213187",
		["245:220:483:8"] = "2213196",
		["90:115:211:359"] = "2213164",
		["90:80:241:92"] = "2213143",
		["95:95:299:88"] = "2213154",
		["95:95:350:335"] = "2213170",
	},
	--[[1435: Swamp of Sorrows]]
	[1435] = {
		["215:365:724:120"] = "272739, 272746",
		["235:205:171:145"] = "272736",
		["240:245:0:262"] = "2213206",
		["245:305:0:140"] = "272759, 272750",
		["256:668:746:0"] = "272756, 272737, 272769",
		["275:240:129:236"] = "272747, 272763",
		["300:275:565:218"] = "272772, 272760, 2213215, 2213216",
		["315:235:286:110"] = "272768, 272770",
		["345:250:552:378"] = "272740, 272773",
		["360:315:279:237"] = "272742, 272751, 272752, 272764",
		["365:305:492:0"] = "2213200, 2213202, 2213203, 2213204",
	},
	--[[1436: Westfall]]
	[1436] = {
		["165:200:488:0"] = "273143",
		["195:240:442:241"] = "273137",
		["200:185:208:375"] = "273142",
		["200:240:524:252"] = "273125",
		["210:215:387:11"] = "273145",
		["215:215:307:29"] = "2212528",
		["220:200:317:331"] = "273130",
		["225:205:328:148"] = "273126",
		["225:210:459:105"] = "273146",
		["225:256:220:102"] = "273149",
		["256:175:339:418"] = "273124",
		["280:190:205:467"] = "273141, 2212527",
		["288:235:523:377"] = "273131, 273134",
		["305:210:204:260"] = "273129, 273133",
	},
	--[[1437: Wetlands]]
	[1437] = {
		["175:128:13:314"] = "273156",
		["185:240:456:125"] = "2212531",
		["190:160:628:176"] = "273181",
		["195:185:247:205"] = "273155",
		["200:185:349:115"] = "273173",
		["200:240:237:41"] = "2212533",
		["205:180:401:21"] = "273164",
		["205:245:527:264"] = "273177",
		["225:185:347:218"] = "273159",
		["225:190:89:142"] = "273171",
		["230:190:470:371"] = "273174",
		["240:175:77:245"] = "273163",
		["256:250:507:115"] = "2212535",
		["300:240:92:82"] = "273178, 273167",
		["350:360:611:230"] = "2213613, 2213614, 2212532, 2212534",
	},

	--[[1438: Teldrassil]]
	[1438] = {
		["128:100:494:548"] = "2213328",
		["128:190:335:313"] = "272807",
		["160:210:382:281"] = "272826",
		["170:240:272:127"] = "272830",
		["180:256:377:93"] = "272822",
		["185:128:368:443"] = "272814",
		["190:128:462:323"] = "2213323",
		["200:200:561:292"] = "272815",
		["225:225:491:153"] = "272811",
		["256:185:436:380"] = "272810",
		["315:256:101:247"] = "272806, 272812",
	},
	--[[1439: Darkshore]]
	[1439] = {
		["150:215:318:162"] = "769206",
		["170:195:468:85"] = "769211",
		["175:158:329:510"] = "271044",
		["175:183:229:485"] = "769210",
		["180:195:365:181"] = "769207",
		["190:205:324:306"] = "271045",
		["195:215:510:0"] = "271043",
		["200:170:305:412"] = "769209",
		["230:190:375:94"] = "769208",
	},
	--[[1440: Ashenvale]]
	[1440] = {
		["128:195:131:137"] = "270380",
		["146:200:856:151"] = "270387",
		["155:150:260:373"] = "270398",
		["165:175:189:324"] = "2212540",
		["180:245:520:238"] = "270402",
		["200:160:796:311"] = "270390",
		["200:205:392:218"] = "2212541",
		["205:185:272:251"] = "270386",
		["210:185:463:141"] = "270400",
		["215:305:205:38"] = "2212542, 2212543",
		["220:195:104:259"] = "2212548",
		["225:255:597:258"] = "270401",
		["235:205:547:426"] = "270375",
		["245:245:19:28"] = "270376",
		["245:255:713:344"] = "270405",
		["255:195:203:158"] = "270389",
		["275:240:356:347"] = "2212544, 2212545",
		["285:185:694:225"] = "270388, 2212547",
	},
	--[[1441: Thousand Needles]]
	[1441] = {
		["190:190:31:155"] = "272968",
		["205:195:259:131"] = "272962",
		["210:180:205:70"] = "272963",
		["210:190:357:264"] = "272954",
		["210:195:391:192"] = "2213363",
		["240:220:492:250"] = "2213395",
		["250:240:179:200"] = "2213369",
		["305:310:0:0"] = "2213348, 2213349, 2213351, 2213352",
		["320:365:610:300"] = "2213371, 2213372, 2213374, 2213375",
	},
	--[[1442: Stonetalon Mountains]]
	[1442] = {
		["125:125:475:433"] = "2213093",
		["125:86:663:582"] = "272650",
		["145:107:572:561"] = "272628",
		["150:150:389:320"] = "272646",
		["190:97:718:571"] = "2213087",
		["200:215:390:145"] = "272624",
		["225:120:668:515"] = "2213088",
		["230:355:210:234"] = "272633, 272647",
		["270:205:247:0"] = "272632, 272641",
		["288:355:457:282"] = "272648, 272634, 272635, 272623",
		["320:275:553:197"] = "272630, 272649, 272642, 272636",
	},
	--[[1443: Desolace]]
	[1443] = {
		["100:100:241:6"] = "2212638",
		["170:160:555:181"] = "2212635",
		["190:220:447:102"] = "271111",
		["195:242:293:426"] = "271122",
		["200:250:554:0"] = "271114",
		["205:145:431:0"] = "271126",
		["205:195:690:444"] = "271105",
		["205:250:311:61"] = "2212632",
		["205:285:590:365"] = "2212636, 2212637",
		["220:220:607:215"] = "2212634",
		["230:230:167:389"] = "271125",
		["245:285:212:215"] = "271106, 271129",
		["275:250:387:244"] = "271127, 2212633",
		["285:245:625:33"] = "271104, 271124",
		["285:280:399:380"] = "271108, 271112, 271113, 271109",
	},
	--[[1444: Feralas]]
	[1444] = {
		["110:110:493:70"] = "2212732",
		["110:170:478:386"] = "2212728",
		["115:115:486:329"] = "2212726",
		["120:195:623:167"] = "2212729",
		["140:165:690:141"] = "271696",
		["145:320:404:256"] = "271700, 271682",
		["150:125:454:0"] = "2212721",
		["155:160:689:233"] = "271675",
		["180:180:208:234"] = "2212734",
		["190:155:305:0"] = "2212733",
		["190:250:540:320"] = "271699",
		["215:293:192:375"] = "2212730, 2212731",
		["225:180:751:198"] = "271680",
		["230:195:454:201"] = "271687",
		["240:220:618:298"] = "2212735",
		["285:245:319:75"] = "271705, 271686",
	},
	--[[1445: Dustwallow Marsh]]
	[1445] = {
		["200:195:660:21"] = "271494",
		["230:205:534:224"] = "271500",
		["250:315:422:0"] = "271507, 271504",
		["255:250:257:313"] = "2212689",
		["280:270:230:0"] = "2212685, 2212686, 2212687, 2212688",
		["285:240:367:381"] = "271503, 271509",
		["400:255:239:189"] = "2212683, 2212684",
	},
	--[[1446: Tanaris]]
	[1446] = {
		["110:140:611:147"] = "2213315",
		["110:180:473:234"] = "272800",
		["120:135:533:104"] = "2213275",
		["150:160:291:434"] = "2213311",
		["155:150:561:256"] = "272789",
		["155:150:592:75"] = "2213281",
		["160:150:395:346"] = "272798",
		["160:190:629:220"] = "2213273",
		["165:180:509:168"] = "2213313",
		["175:165:421:91"] = "272774",
		["180:200:252:199"] = "272792",
		["185:250:203:286"] = "272781",
		["195:175:299:100"] = "272776",
		["195:210:323:359"] = "272784",
		["205:145:325:289"] = "272782",
		["205:157:445:511"] = "272801",
		["210:175:254:0"] = "272788",
		["215:175:499:293"] = "272795",
		["215:180:363:194"] = "272799",
		["220:210:449:372"] = "272805",
	},
	--[[1447: Azshara]]
	[1447] = {
		["120:155:818:107"] = "270434",
		["145:215:422:95"] = "2212573",
		["160:210:404:194"] = "270412",
		["190:200:681:153"] = "2212567",
		["200:150:77:331"] = "2212555",
		["215:175:84:229"] = "2212574",
		["220:255:191:369"] = "2212554",
		["225:180:35:422"] = "2212564",
		["235:140:478:44"] = "2212560",
		["235:270:250:106"] = "2212571, 2212572",
		["240:125:552:499"] = "270410",
		["240:155:499:119"] = "2212568",
		["245:185:644:40"] = "270432",
		["265:280:238:221"] = "270414, 2212561, 2212562, 2212563",
		["270:300:479:201"] = "2212550, 2212551, 2212552, 2212553",
		["315:200:296:429"] = "270409, 2212559",
		["370:220:389:353"] = "2212565, 2212566",
		["395:128:396:540"] = "2212569, 2212570",
		["570:170:366:0"] = "2212556, 2212557, 2212558",
	},
	--[[1448: Felwood]]
	[1448] = {
		["145:159:496:509"] = "271657",
		["160:145:548:90"] = "271653",
		["165:155:332:465"] = "271663",
		["175:135:408:533"] = "271658",
		["185:160:405:429"] = "271659",
		["195:170:330:29"] = "271652",
		["215:215:420:54"] = "271673",
		["235:145:292:263"] = "271666",
		["235:155:297:381"] = "271664",
		["235:200:307:123"] = "271665",
		["240:145:483:0"] = "271660",
		["245:128:271:331"] = "271669",
	},
	--[[1449: Un'Goro Crater]]
	[1449] = {
		["285:285:582:67"] = "273051, 2213483, 2213484, 2213486",
		["295:270:367:178"] = "273042, 273065, 273050, 273036",
		["310:355:560:240"] = "273072, 273039, 273037, 273063",
		["315:345:121:151"] = "273043, 273075, 273069, 273061",
		["345:285:158:368"] = "273046, 273053, 273071, 273047",
		["345:285:367:380"] = "273059, 273066, 273073, 273054",
		["570:265:160:6"] = "273052, 273062, 273057, 273058, 2213490, 2213491",
	},
	--[[1450: Moonglade]]
	[1450] = { ["555:510:244:89"] = "252844, 252845, 252846, 252847, 2212870, 2212872" },
	--[[1451: Silithus]]
	[1451] = {
		["288:256:116:413"] = "272564, 272553",
		["320:256:344:197"] = "272573, 272545",
		["320:289:104:24"] = "272581, 272562, 2213052, 2213053",
		["384:384:500:65"] = "272580, 272544, 2213048, 2213049",
		["384:512:97:144"] = "272559, 272543, 272574, 272575",
		["512:320:265:12"] = "272565, 272566, 272577, 272546",
		["512:384:245:285"] = "272567, 272547, 272555, 272548",
	},
	--[[1452: Wintergrasp]]
	[1452] = {
		["125:165:611:242"] = "273206",
		["145:125:617:158"] = "273200",
		["165:140:593:340"] = "273199",
		["165:200:509:107"] = "273191",
		["175:185:555:27"] = "273203",
		["185:160:392:137"] = "273207",
		["185:180:493:258"] = "273185",
		["200:160:523:376"] = "273198",
		["215:185:401:198"] = "273192",
		["230:120:229:243"] = "273187",
		["240:140:222:172"] = "273202",
		["250:180:368:7"] = "273184",
		["255:205:447:441"] = "2213650",
	},

	--[[1459: Alterac Valley]]
	[1459] = {
		["235:290:399:375"] = "270314, 270315",
		["270:240:348:13"] = "270331, 270325",
		["300:300:335:172"] = "270320, 270321, 270322, 270323",
	},
}

local graph_lines = {}
local LineFrame = CreateFrame("frame")

local deathlog_menu = nil

local subtitle_data = {
	{
		"Date",
		60,
		function(_entry, _server_name)
			return date("%m/%d/%y", _entry["date"]) or ""
		end,
	},
	{
		"Lvl",
		30,
		function(_entry, _server_name)
			return _entry["level"] or ""
		end,
	},
	{
		"Name",
		90,
		function(_entry, _server_name)
			return _entry["name"] or ""
		end,
	},
	{
		"Class",
		60,
		function(_entry, _server_name)
			local class_str, _, _ = GetClassInfo(_entry["class_id"])
			if RAID_CLASS_COLORS[class_str:upper()] then
				return "|c" .. RAID_CLASS_COLORS[class_str:upper()].colorStr .. class_str .. "|r"
			end
			return class_str or ""
		end,
	},
	{
		"Race",
		60,
		function(_entry, _server_name)
			local race_info = C_CreatureInfo.GetRaceInfo(_entry["race_id"])
			return race_info.raceName or ""
		end,
	},
	{
		"Guild",
		120,
		function(_entry, _server_name)
			return _entry["guild"] or ""
		end,
	},
	{
		"Zone/Instance",
		100,
		function(_entry, _server_name)
			if _entry["map_id"] == nil then
				if _entry["instance_id"] ~= nil then
					return _entry["instance_id"]
				else
					return "-----------"
				end
			end
			local map_info = C_Map.GetMapInfo(_entry["map_id"])
			if map_info then
				return map_info.name
			end
			return "-----------"
		end,
	},
	{
		"Death Source",
		140,
		function(_entry, _server_name)
			return id_to_npc[_entry["source_id"]] or ""
		end,
	},
	{
		"Last Words",
		200,
		function(_entry, _server_name)
			return _entry["last_words"] or ""
		end,
	},
}

local AceGUI = LibStub("AceGUI-3.0")

local font_container = CreateFrame("Frame")
font_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
font_container:SetSize(100, 100)
font_container:Show()
local row_entry = {}
local font_strings = {} -- idx/columns
local header_strings = {} -- columns
local row_backgrounds = {} --idx

for idx, v in ipairs(subtitle_data) do
	header_strings[v[1]] = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	if idx == 1 then
		header_strings[v[1]]:SetPoint("LEFT", font_container, "LEFT", 0, 0)
	else
		header_strings[v[1]]:SetPoint("LEFT", last_font_string, "RIGHT", 0, 0)
	end
	last_font_string = header_strings[v[1]]
	header_strings[v[1]]:SetJustifyH("LEFT")
	header_strings[v[1]]:SetWordWrap(false)

	if idx + 1 <= #subtitle_data then
		header_strings[v[1]]:SetWidth(v[2])
	end
	header_strings[v[1]]:SetTextColor(0.7, 0.7, 0.7)
	header_strings[v[1]]:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
end

for i = 1, 100 do
	font_strings[i] = {}
	local last_font_string = nil
	for idx, v in ipairs(subtitle_data) do
		font_strings[i][v[1]] = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		if idx == 1 then
			font_strings[i][v[1]]:SetPoint("LEFT", font_container, "LEFT", 0, 0)
		else
			font_strings[i][v[1]]:SetPoint("LEFT", last_font_string, "RIGHT", 0, 0)
		end
		last_font_string = font_strings[i][v[1]]
		font_strings[i][v[1]]:SetJustifyH("LEFT")
		font_strings[i][v[1]]:SetWordWrap(false)

		if idx + 1 <= #subtitle_data then
			font_strings[i][v[1]]:SetWidth(v[2])
		end
		font_strings[i][v[1]]:SetTextColor(1, 1, 1)
		font_strings[i][v[1]]:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	end

	row_backgrounds[i] = font_container:CreateTexture(nil, "OVERLAY")
	row_backgrounds[i]:SetDrawLayer("OVERLAY", 2)
	row_backgrounds[i]:SetVertexColor(0.5, 0.5, 0.5, (i % 2) / 10)
	row_backgrounds[i]:SetHeight(16)
	row_backgrounds[i]:SetWidth(1600)
	row_backgrounds[i]:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
end

local deadliest_creatures_container = CreateFrame("Frame")
deadliest_creatures_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
local function createDeadliestCreaturesEntry()
	local frame = CreateFrame("Frame")
	frame:SetParent(deadliest_creatures_container)
	frame:SetWidth(60)
	frame:SetHeight(20)

	frame.background = frame:CreateTexture(nil, "OVERLAY")
	frame.background:SetPoint("LEFT", frame, "LEFT", 0, 0)
	frame.background:SetVertexColor(0.6, 0.2, 0.2)
	frame.background:SetTexture("Interface/TARGETINGFRAME/UI-StatusBar.PNG")
	frame.background:SetHeight(14)
	frame.background:SetWidth(20)
	frame.background:Show()

	frame.creature_name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.creature_name:SetPoint("LEFT", frame, "LEFT", 10, 0)
	frame.creature_name:SetFont("Fonts\\blei00d.TTF", 14, "OUTLINE")
	frame.creature_name:SetTextColor(0.9, 0.9, 0.9)
	frame.creature_name:SetText("AAA")
	frame.creature_name:Show()

	-- frame.rank_text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	-- frame.rank_text:SetPoint("LEFT", frame, "LEFT", 10, 0)
	-- frame.rank_text:SetText("")
	-- frame.rank_text:Show()

	frame.num_kills_text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.num_kills_text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	frame.num_kills_text:SetText("")
	frame.num_kills_text:SetJustifyH("RIGHT")
	frame.num_kills_text:Show()

	frame.SetBackgroundWidth = function(self, width)
		self.background:SetWidth(width)
	end

	frame.SetCreatureName = function(self, creature_name)
		frame.creature_name:SetText(creature_name)
	end

	frame.SetNumKills = function(self, num)
		frame.num_kills_text:SetText(num .. " kills")
	end

	return frame
end
local deadliest_creatures_textures = {}
for i = 1, 10 do
	deadliest_creatures_textures[i] = createDeadliestCreaturesEntry()
	-- deadliest_creatures_textures[i].rank_text:SetText(i)
end

local map_container = CreateFrame("Frame")
map_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
map_container:SetSize(100, 100)
map_container:Show()
map_container.current_map_id = nil
local map_textures = {}
for i = 1, 12 do
	map_textures[i] = map_container:CreateTexture(nil, "OVERLAY")
	map_textures[i]:SetDrawLayer("OVERLAY", 2)
	map_textures[i]:SetVertexColor(1, 1, 1, 1)
end
map_textures[1]:SetPoint("TOPLEFT", map_container, "TOPLEFT", 0, 0)
map_textures[2]:SetPoint("LEFT", map_textures[1], "RIGHT", 0, 0)
map_textures[3]:SetPoint("LEFT", map_textures[2], "RIGHT", 0, 0)
map_textures[4]:SetPoint("LEFT", map_textures[3], "RIGHT", 0, 0)
map_textures[5]:SetPoint("TOP", map_textures[1], "BOTTOM", 0, 0)
map_textures[6]:SetPoint("LEFT", map_textures[5], "RIGHT", 0, 0)
map_textures[7]:SetPoint("LEFT", map_textures[6], "RIGHT", 0, 0)
map_textures[8]:SetPoint("LEFT", map_textures[7], "RIGHT", 0, 0)
map_textures[9]:SetPoint("TOP", map_textures[5], "BOTTOM", 0, 0)
map_textures[10]:SetPoint("LEFT", map_textures[9], "RIGHT", 0, 0)
map_textures[11]:SetPoint("LEFT", map_textures[10], "RIGHT", 0, 0)
map_textures[12]:SetPoint("LEFT", map_textures[11], "RIGHT", 0, 0)

local map_texture_masks = {}
map_texture_masks[1] = map_container:CreateMaskTexture()
map_texture_masks[1]:SetRotation(3.14 + 3.14 / 2)
map_texture_masks[1]:SetPoint("CENTER", map_textures[1], "CENTER", 0, 0)
map_texture_masks[1]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\corner_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[1]:AddMaskTexture(map_texture_masks[1])

map_texture_masks[4] = map_container:CreateMaskTexture()
map_texture_masks[4]:SetRotation(3.14)
map_texture_masks[4]:SetPoint("CENTER", map_textures[4], "CENTER", -30, 0)
map_texture_masks[4]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\corner_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[4]:AddMaskTexture(map_texture_masks[4])

map_texture_masks[9] = map_container:CreateMaskTexture()
map_texture_masks[9]:SetPoint("CENTER", map_textures[9], "CENTER", 0, 65)
map_texture_masks[9]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\corner_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[9]:AddMaskTexture(map_texture_masks[9])

map_texture_masks[12] = map_container:CreateMaskTexture()
map_texture_masks[12]:SetPoint("CENTER", map_textures[12], "CENTER", -30, 65)
map_texture_masks[12]:SetRotation(3.14 / 2)
map_texture_masks[12]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\corner_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[12]:AddMaskTexture(map_texture_masks[12])

map_texture_masks[2] = map_container:CreateMaskTexture()
map_texture_masks[2]:SetPoint("CENTER", map_textures[2], "CENTER", 0, 0)
map_texture_masks[2]:SetRotation(3.14)
map_texture_masks[2]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[2]:AddMaskTexture(map_texture_masks[2])
map_texture_masks[3] = map_container:CreateMaskTexture()
map_texture_masks[3]:SetPoint("CENTER", map_textures[3], "CENTER", 0, 0)
map_texture_masks[3]:SetRotation(3.14)
map_texture_masks[3]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[3]:AddMaskTexture(map_texture_masks[3])

map_texture_masks[10] = map_container:CreateMaskTexture()
map_texture_masks[10]:SetPoint("CENTER", map_textures[10], "CENTER", 0, 65)
map_texture_masks[10]:SetRotation(0)
map_texture_masks[10]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[10]:AddMaskTexture(map_texture_masks[10])
map_texture_masks[11] = map_container:CreateMaskTexture()
map_texture_masks[11]:SetPoint("CENTER", map_textures[11], "CENTER", 0, 65)
map_texture_masks[11]:SetRotation(0)
map_texture_masks[11]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[11]:AddMaskTexture(map_texture_masks[11])

map_texture_masks[5] = map_container:CreateMaskTexture()
map_texture_masks[5]:SetPoint("CENTER", map_textures[5], "CENTER", 0, 0)
map_texture_masks[5]:SetRotation(3.14 + 3.14 / 2)
map_texture_masks[5]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[5]:AddMaskTexture(map_texture_masks[5])

map_texture_masks[8] = map_container:CreateMaskTexture()
map_texture_masks[8]:SetPoint("CENTER", map_textures[8], "CENTER", -30, 0)
map_texture_masks[8]:SetRotation(3.14 - 3.14 / 2)
map_texture_masks[8]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[8]:AddMaskTexture(map_texture_masks[8])

local function createMapHighlightButton(
	name,
	topleft,
	scalex,
	scaley,
	button_topleft,
	button_scalex,
	button_scaley,
	map_id
)
	local button = CreateFrame("Button", "DeathlogHighlightButton" .. name, map_container)
	button.map_id = map_id
	button.Texture = button:CreateTexture(button:GetName() .. "Texture", "BACKGROUND")
	button.Texture:Hide()
	button.HighlightTexture = button:CreateTexture(button:GetName() .. "HighlightTexture", "HIGHLIGHT")
	button.HighlightTexture:SetBlendMode("ADD")
	button.HighlightTexture:SetAllPoints(button.Texture)
	button.HighlightTexture:SetTexture("Interface\\WorldMap\\" .. name .. "\\" .. name .. "Highlight.PNG")
	button:Hide()

	button.topleft = topleft
	button.scalex = scalex
	button.scaley = scaley

	button.button_topleft = button_topleft
	button.button_scalex = button_scalex
	button.button_scaley = button_scaley
	return button
end

local overlay_highlight = map_container:CreateTexture(nil, "OVERLAY")
overlay_highlight:SetDrawLayer("OVERLAY", 6)
overlay_highlight:SetBlendMode("ADD")
overlay_highlight:Hide()

local average_class_container = CreateFrame("Frame")
average_class_container:SetSize(100, 100)
average_class_container:Show()

local average_class_subtitles = {
	{ "Class", 20, "LEFT", 60 },
	{ "#", 50, "RIGHT", 40 },
	{ "%", 90, "RIGHT", 50 },
	{ "Avg.", 130, "RIGHT", 50 },
}

local average_class_header_font_strings = {}
for _, v in ipairs(average_class_subtitles) do
	average_class_header_font_strings[v[1]] = average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	average_class_header_font_strings[v[1]]:SetPoint("TOPLEFT", average_class_container, "TOPLEFT", v[2], 2)
	average_class_header_font_strings[v[1]]:SetFont("Fonts\\blei00d.TTF", 15, "")
	average_class_header_font_strings[v[1]]:SetJustifyH(v[3])
	average_class_header_font_strings[v[1]]:SetWidth(50)
	average_class_header_font_strings[v[1]]:SetText(v[1])
end

local average_class_font_strings = {}
local sep = -18
for k, class_id in pairs(class_tbl) do
	average_class_font_strings[class_id] = {}
	for _, v in ipairs(average_class_subtitles) do
		average_class_font_strings[class_id][v[1]] =
			average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		average_class_font_strings[class_id][v[1]]:SetPoint(
			"TOPLEFT",
			average_class_container,
			"TOPLEFT",
			v[2],
			sep + 2
		)
		average_class_font_strings[class_id][v[1]]:SetFont("Fonts\\blei00d.TTF", 14, "")
		average_class_font_strings[class_id][v[1]]:SetJustifyH(v[3])
		average_class_font_strings[class_id][v[1]]:SetWidth(50)
		average_class_font_strings[class_id][v[1]]:SetTextColor(1, 1, 1, 1)
	end
	sep = sep - 16
end

average_class_font_strings["all"] = {}
for _, v in ipairs(average_class_subtitles) do
	average_class_font_strings["all"][v[1]] = average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	average_class_font_strings["all"][v[1]]:SetPoint("TOPLEFT", average_class_container, "TOPLEFT", v[2], sep + 2)
	average_class_font_strings["all"][v[1]]:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
	average_class_font_strings["all"][v[1]]:SetTextColor(1, 1, 1, 1)
end

local function clearDeathlogMenuLogData()
	for i, v in ipairs(font_strings) do
		for _, col in ipairs(subtitle_data) do
			v[col[1]]:SetText("")
		end
	end
end

local function setDeathlogMenuLogData(data)
	local ordered = deathlogOrderBy(data, function(t, a, b)
		return tonumber(t[b]["date"]) < tonumber(t[a]["date"])
	end)
	for idx, v in ipairs(ordered) do
		for _, col in ipairs(subtitle_data) do
			font_strings[idx][col[1]]:SetText(col[3](v, ""))
		end
		if idx > 99 then
			break
		end
	end
	if #ordered == 1 then
		deathlog_menu:SetStatusText(#ordered .. " result")
	else
		deathlog_menu:SetStatusText(#ordered .. " results")
	end
	-- for server_name,entry_tbl in pairs(data) do
	--   for checksum,v in pairs(entry_tbl) do
	-- for _,col in ipairs(subtitle_data) do
	-- font_strings[c][col[1]]:SetText(col[3](v, server_name))
	-- end
	-- c=c+1
	-- if c > 99 then break end
	--   end
	-- end
end

local _deathlog_data = {}
local _general_stats = {}
local initialized = false

local function drawLogTab(container)
	local scroll_container = AceGUI:Create("SimpleGroup")
	scroll_container:SetFullWidth(true)
	scroll_container:SetFullHeight(true)
	scroll_container:SetLayout("Fill")
	deathlog_tabcontainer:AddChild(scroll_container)

	local scroll_frame = AceGUI:Create("ScrollFrame")
	scroll_frame:SetLayout("Flow")
	scroll_container:AddChild(scroll_frame)

	local name_filter = nil
	local guidl_filter = nil
	local class_filter = nil
	local race_filter = nil
	local zone_filter = nil
	local min_level_filter = nil
	local max_level_filter = nil
	local death_source_filter = nil
	local filter = function(server_name, _entry)
		if name_filter ~= nil then
			if name_filter(server_name, _entry) == false then
				return false
			end
		end
		if min_level_filter ~= nil then
			if min_level_filter(server_name, _entry) == false then
				return false
			end
		end
		if max_level_filter ~= nil then
			if max_level_filter(server_name, _entry) == false then
				return false
			end
		end
		if death_source_filter ~= nil then
			if death_source_filter(server_name, _entry) == false then
				return false
			end
		end
		if class_filter ~= nil then
			if class_filter(server_name, _entry) == false then
				return false
			end
		end
		if race_filter ~= nil then
			if race_filter(server_name, _entry) == false then
				return false
			end
		end
		if zone_filter ~= nil then
			if zone_filter(server_name, _entry) == false then
				return false
			end
		end
		if guild_filter ~= nil then
			if guild_filter(server_name, _entry) == false then
				return false
			end
		end
		return true
	end

	local server_search_box = AceGUI:Create("DeathlogDropdown")
	server_search_box:SetWidth(150)
	server_search_box:SetDisabled(false)
	server_search_box:SetLabel("Server")
	server_search_box:SetPoint("TOP", 2, 5)
	server_search_box:AddItem("", "")
	for server_name, _ in pairs(_deathlog_data) do
		server_search_box:AddItem(server_name, server_name)
	end
	server_search_box:SetText("")
	scroll_frame:AddChild(server_search_box)

	local class_search_box = AceGUI:Create("DeathlogDropdown")
	class_search_box:SetWidth(100)
	class_search_box:SetDisabled(false)
	class_search_box:SetLabel("Class")
	class_search_box:SetPoint("TOP", 0, 0)
	class_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	class_search_box:AddItem("", "")
	for class_name, _ in pairs(class_tbl) do
		class_search_box:AddItem(class_name, class_name)
	end
	class_search_box:SetCallback("OnValueChanged", function()
		local key = class_search_box:GetValue()
		if key ~= "" then
			class_filter = function(_, _entry)
				if class_tbl[key] == tonumber(_entry["class_id"]) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			class_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(class_search_box)

	local race_search_box = AceGUI:Create("DeathlogDropdown")
	race_search_box:SetWidth(100)
	race_search_box:SetDisabled(false)
	race_search_box:SetLabel("Race")
	race_search_box:SetPoint("TOP", 0, 0)
	race_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	race_search_box:AddItem("", "")
	for race_name, _ in pairs(race_tbl) do
		race_search_box:AddItem(race_name, race_name)
	end
	race_search_box:SetCallback("OnValueChanged", function()
		local key = race_search_box:GetValue()
		if key ~= "" then
			race_filter = function(_, _entry)
				if race_tbl[key] == tonumber(_entry["race_id"]) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			race_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(race_search_box)

	local zone_search_box = AceGUI:Create("DeathlogDropdown")
	zone_search_box:SetWidth(140)
	zone_search_box:SetDisabled(false)
	zone_search_box:SetLabel("Zone")
	zone_search_box:SetPoint("TOP", 0, 0)
	zone_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	zone_search_box:AddItem("", "")
	for zone_name, _ in pairs(zone_tbl) do
		zone_search_box:AddItem(zone_name, zone_name)
	end
	zone_search_box:SetCallback("OnValueChanged", function()
		local key = zone_search_box:GetValue()
		if key ~= "" then
			zone_filter = function(_, _entry)
				if zone_tbl[key] == tonumber(_entry["map_id"]) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			zone_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(zone_search_box)

	local min_level_box = AceGUI:Create("DeathlogEditBox")
	min_level_box:SetWidth(60)
	min_level_box:SetDisabled(false)
	min_level_box:SetLabel("min lvl")
	min_level_box:SetPoint("TOP", 2, 5)
	min_level_box:DisableButton(false)
	min_level_box:SetCallback("OnEnterPressed", function()
		local text = min_level_box:GetText()
		if #text > 0 then
			min_level_filter = function(_, _entry)
				if tonumber(text) ~= nil and tonumber(text) < _entry["level"] then
					return true
				end
				return false
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			min_level_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(min_level_box)

	local max_level_box = AceGUI:Create("DeathlogEditBox")
	max_level_box:SetWidth(60)
	max_level_box:SetDisabled(false)
	max_level_box:SetPoint("TOP", 2, 5)
	max_level_box:SetLabel("max lvl")
	max_level_box:DisableButton(false)
	max_level_box:SetCallback("OnEnterPressed", function()
		local text = max_level_box:GetText()
		if #text > 0 then
			max_level_filter = function(_, _entry)
				if tonumber(text) ~= nil and tonumber(text) > _entry["level"] then
					return true
				end
				return false
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			max_level_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(max_level_box)

	local player_search_box = AceGUI:Create("DeathlogEditBox")
	player_search_box:SetWidth(120)
	player_search_box:SetDisabled(false)
	player_search_box:SetLabel("Name")
	player_search_box:SetPoint("TOP", 0, 0)
	player_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	player_search_box:DisableButton(false)
	player_search_box:SetCallback("OnEnterPressed", function()
		local text = player_search_box:GetText()
		if #text > 0 then
			name_filter = function(_, _entry)
				if string.find(string.lower(_entry["name"]), string.lower(text)) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			name_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(player_search_box)

	local guild_search_box = AceGUI:Create("DeathlogEditBox")
	guild_search_box:SetWidth(120)
	guild_search_box:SetDisabled(false)
	guild_search_box:SetLabel("Guild")
	guild_search_box:SetPoint("TOP", 0, 0)
	guild_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	guild_search_box:DisableButton(false)
	guild_search_box:SetCallback("OnEnterPressed", function()
		local text = guild_search_box:GetText()
		if #text > 0 then
			guild_filter = function(_, _entry)
				if string.find(string.lower(_entry["guild"]), string.lower(text)) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			guild_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(guild_search_box)

	local death_source_box = AceGUI:Create("DeathlogEditBox")
	death_source_box:SetWidth(150)
	death_source_box:SetDisabled(false)
	death_source_box:SetLabel("Death source")
	death_source_box:SetPoint("TOP", 2, 5)
	death_source_box:DisableButton(false)
	death_source_box:SetCallback("OnEnterPressed", function()
		local text = death_source_box:GetText()
		if #text > 0 then
			death_source_filter = function(_, _entry)
				if
					id_to_npc[_entry["source_id"]] ~= nil
					and string.find(string.lower(id_to_npc[_entry["source_id"]]), string.lower(text))
				then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			death_source_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(death_source_box)

	local header_label = AceGUI:Create("InteractiveLabel")
	header_label:SetFullWidth(true)
	header_label:SetHeight(60)
	header_label.font_strings = {}

	header_strings[subtitle_data[1][1]]:SetPoint("LEFT", header_label.frame, "LEFT", 0, 0)
	header_strings[subtitle_data[1][1]]:Show()
	for _, v in ipairs(subtitle_data) do
		header_strings[v[1]]:SetParent(header_label.frame)
		header_strings[v[1]]:SetText(v[1])
	end

	header_label:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
	header_label:SetColor(1, 1, 1)
	header_label:SetText(" ")
	scroll_frame:AddChild(header_label)

	local deathlog_group = AceGUI:Create("ScrollFrame")
	deathlog_group:SetFullWidth(true)
	deathlog_group:SetHeight(440)
	scroll_frame:AddChild(deathlog_group)
	font_container:SetParent(deathlog_group.frame)
	-- font_container:SetPoint("TOP", deathlog_group.frame, "TOP", 0, -100)
	font_container:SetHeight(400)
	font_container:Show()
	for i = 1, 100 do
		local idx = 101 - i
		local _entry = AceGUI:Create("InteractiveLabel")
		_entry:SetHighlight("Interface\\Glues\\CharacterSelect\\Glues-CharacterSelect-Highlight")

		font_strings[i][subtitle_data[1][1]]:SetPoint("LEFT", _entry.frame, "LEFT", 0, 0)
		font_strings[i][subtitle_data[1][1]]:Show()
		for _, v in ipairs(subtitle_data) do
			font_strings[i][v[1]]:SetParent(_entry.frame)
		end

		row_backgrounds[i]:SetPoint("CENTER", _entry.frame, "CENTER", 0, 0)
		row_backgrounds[i]:SetParent(_entry.frame)

		_entry:SetHeight(40)
		_entry:SetFullWidth(true)
		_entry:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
		_entry:SetColor(1, 1, 1)
		_entry:SetText(" ")

		function _entry:deselect()
			for _, v in pairs(_entry.font_strings) do
				v:SetTextColor(1, 1, 1)
			end
		end

		function _entry:select()
			selected = idx
			for _, v in pairs(_entry.font_strings) do
				v:SetTextColor(1, 1, 0)
			end
		end

		_entry:SetCallback("OnLeave", function(widget)
			if _entry.player_data == nil then
				return
			end
			GameTooltip:Hide()
		end)

		_entry:SetCallback("OnClick", function()
			if _entry.player_data == nil then
				return
			end
			local click_type = GetMouseButtonClicked()

			if click_type == "LeftButton" then
				if selected then
					row_entry[selected]:deselect()
				end
				_entry:select()
			elseif click_type == "RightButton" then
				local dropDown = CreateFrame("Frame", "WPDemoContextMenu", UIParent, "UIDropDownMenuTemplate")
				-- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
				UIDropDownMenu_Initialize(dropDown, WPDropDownDemo_Menu, "MENU")
				ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
				if _entry["player_data"]["map_id"] and _entry["player_data"]["map_pos"] then
					death_tomb_frame.map_id = _entry["player_data"]["map_id"]
					local x, y = strsplit(",", _entry["player_data"]["map_pos"], 2)
					death_tomb_frame.coordinates = { x, y }
				end
			end
		end)

		_entry:SetCallback("OnEnter", function(widget)
			if _entry.player_data == nil then
				return
			end
			GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)

			if string.sub(_entry.player_data["name"], #_entry.player_data["name"]) == "s" then
				GameTooltip:AddDoubleLine(
					_entry.player_data["name"] .. "' Death",
					"Lvl. " .. _entry.player_data["level"],
					1,
					1,
					1,
					0.5,
					0.5,
					0.5
				)
			else
				GameTooltip:AddDoubleLine(
					_entry.player_data["name"] .. "'s Death",
					"Lvl. " .. _entry.player_data["level"],
					1,
					1,
					1,
					0.5,
					0.5,
					0.5
				)
			end
			GameTooltip:AddLine("Name: " .. _entry.player_data["name"], 1, 1, 1)
			GameTooltip:AddLine("Guild: " .. _entry.player_data["guild"], 1, 1, 1)

			local race_info = C_CreatureInfo.GetRaceInfo(_entry.player_data["race_id"])
			if race_info then
				GameTooltip:AddLine("Race: " .. race_info.raceName, 1, 1, 1)
			end

			if _entry.player_data["class_id"] then
				local class_str, _, _ = GetClassInfo(_entry.player_data["class_id"])
				if class_str then
					GameTooltip:AddLine("Class: " .. class_str, 1, 1, 1)
				end
			end

			if _entry.player_data["source_id"] then
				local source_id = id_to_npc[_entry.player_data["source_id"]]
				if source_id then
					GameTooltip:AddLine("Killed by: " .. source_id, 1, 1, 1, true)
				elseif environment_damage[_entry.player_data["source_id"]] then
					GameTooltip:AddLine(
						"Died from: " .. environment_damage[_entry.player_data["source_id"]],
						1,
						1,
						1,
						true
					)
				end
			end

			if race_name then
				GameTooltip:AddLine("Race: " .. race_name, 1, 1, 1)
			end

			if _entry.player_data["map_id"] then
				local map_info = C_Map.GetMapInfo(_entry.player_data["map_id"])
				if map_info then
					GameTooltip:AddLine("Zone: " .. map_info.name, 1, 1, 1, true)
				end
			end

			if _entry.player_data["map_pos"] then
				GameTooltip:AddLine("Loc: " .. _entry.player_data["map_pos"], 1, 1, 1, true)
			end

			if _entry.player_data["date"] then
				GameTooltip:AddLine("Date: " .. _entry.player_data["date"], 1, 1, 1, true)
			end

			if _entry.player_data["last_words"] then
				GameTooltip:AddLine("Last words: " .. _entry.player_data["last_words"], 1, 1, 0, true)
			end
			GameTooltip:Show()
		end)

		deathlog_group:SetScroll(0)
		deathlog_group.scrollbar:Hide()
		deathlog_group:AddChild(_entry)
	end
	scroll_frame.scrollbar:Hide()
end

local function drawStatisticsTab(container)
	local update_functions = {}
	local num_recorded_kills = 0

	local scroll_container = AceGUI:Create("SimpleGroup")
	scroll_container:SetFullWidth(true)
	scroll_container:SetFullHeight(true)
	scroll_container:SetLayout("Fill")
	deathlog_tabcontainer:AddChild(scroll_container)

	local scroll_frame = AceGUI:Create("SimpleGroup")
	scroll_frame:SetLayout("Flow")
	scroll_container:AddChild(scroll_frame)

	local title_label = AceGUI:Create("Heading")
	title_label:SetFullWidth(true)
	title_label:SetText("Death Statistics - Azeroth")
	title_label.label:SetFont("Fonts\\blei00d.TTF", 24, "")
	-- title_label.label:SetJustifyH("CENTER")
	scroll_frame:AddChild(title_label)
	local function modifyTitle(zone)
		title_label:SetText("Death Statistics - " .. zone)
	end

	local general_stats_column = AceGUI:Create("SimpleGroup")
	general_stats_column:SetWidth(375)
	general_stats_column:SetHeight(450)
	general_stats_column:SetLayout("List")
	scroll_frame:AddChild(general_stats_column)

	average_class_container:SetParent(scroll_frame.frame)
	average_class_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 820, -50)
	average_class_container:SetWidth(200)
	average_class_container:SetHeight(200)

	if average_class_container.heading == nil then
		average_class_container.heading = average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		average_class_container.heading:SetText("By Class")
		average_class_container.heading:SetFont("Fonts\\blei00d.TTF", 18, "")
		average_class_container.heading:SetJustifyV("TOP")
		average_class_container.heading:SetTextColor(0.9, 0.9, 0.9)
		average_class_container.heading:SetPoint("TOP", average_class_container, "TOP", 0, 20)
		average_class_container.heading:Show()
	end

	if average_class_container.left == nil then
		average_class_container.left = average_class_container:CreateTexture(nil, "BACKGROUND")
		average_class_container.left:SetHeight(8)
		average_class_container.left:SetPoint("LEFT", average_class_container.heading, "LEFT", -50, 0)
		average_class_container.left:SetPoint("RIGHT", average_class_container.heading, "LEFT", -5, 0)
		average_class_container.left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		average_class_container.left:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	if average_class_container.right == nil then
		average_class_container.right = average_class_container:CreateTexture(nil, "BACKGROUND")
		average_class_container.right:SetHeight(8)
		average_class_container.right:SetPoint("RIGHT", average_class_container.heading, "RIGHT", 50, 0)
		average_class_container.right:SetPoint("LEFT", average_class_container.heading, "RIGHT", 5, 0)
		average_class_container.right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		average_class_container.right:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	local function updateClassAverages()
		local entry_data = {}
		local map_id = map_container.current_map_id
		if map_id == 1414 or map_id == 1415 then
			return
		end
		if map_id == 947 then
			map_id = "all"
		end
		if _general_stats["all"][map_id] == nil then
			return
		end

		for k, class_id in pairs(class_tbl) do
			local v = _general_stats["all"][map_id][class_id]
			if v == nil then
				entry_data[class_id] = {}
				entry_data[class_id]["Class"] = k
				entry_data[class_id]["#"] = "-"
				entry_data[class_id]["%"] = "-"
				entry_data[class_id]["Avg."] = "-"
			else
				local class_str = ""
				if class_id ~= "all" then
					class_str, _, _ = GetClassInfo(class_id)
				else
					class_str = "all"
				end
				entry_data[class_id] = {}
				entry_data[class_id]["Class"] = class_str
				entry_data[class_id]["#"] = v["all"]["num_entries"]
				entry_data[class_id]["%"] = string.format(
					"%.1f",
					v["all"]["num_entries"] / _general_stats["all"][map_id]["all"]["all"]["num_entries"] * 100.0
				) .. "%"
				entry_data[class_id]["Avg."] = string.format("%.1f", v["all"]["avg_lvl"])
			end
		end
		for k, class_id in pairs(class_tbl) do
			for _, v in ipairs(average_class_subtitles) do
				average_class_font_strings[class_id][v[1]]:SetText(entry_data[class_id][v[1]])
			end
		end
	end

	if deadliest_creatures_container.heading == nil then
		deadliest_creatures_container.heading =
			deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		deadliest_creatures_container.heading:SetText("Deadliest Creatures")
		deadliest_creatures_container.heading:SetFont("Fonts\\blei00d.TTF", 18, "")
		deadliest_creatures_container.heading:SetJustifyV("TOP")
		deadliest_creatures_container.heading:SetTextColor(0.9, 0.9, 0.9)
		deadliest_creatures_container.heading:SetPoint("TOP", deadliest_creatures_container, "TOP", 0, -20)
		deadliest_creatures_container.heading:Show()
	end

	if deadliest_creatures_container.left == nil then
		deadliest_creatures_container.left = deadliest_creatures_container:CreateTexture(nil, "BACKGROUND")
		deadliest_creatures_container.left:SetHeight(8)
		deadliest_creatures_container.left:SetPoint("LEFT", deadliest_creatures_container.heading, "LEFT", -30, 0)
		deadliest_creatures_container.left:SetPoint("RIGHT", deadliest_creatures_container.heading, "LEFT", -5, 0)
		deadliest_creatures_container.left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		deadliest_creatures_container.left:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	if deadliest_creatures_container.right == nil then
		deadliest_creatures_container.right = deadliest_creatures_container:CreateTexture(nil, "BACKGROUND")
		deadliest_creatures_container.right:SetHeight(8)
		deadliest_creatures_container.right:SetPoint("RIGHT", deadliest_creatures_container.heading, "RIGHT", 30, 0)
		deadliest_creatures_container.right:SetPoint("LEFT", deadliest_creatures_container.heading, "RIGHT", 5, 0)
		deadliest_creatures_container.right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		deadliest_creatures_container.right:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	local function refreshDeadlyUnits()
		num_recorded_kills = 0
		for i = 1, 10 do
			deadliest_creatures_textures[i]:Hide()
		end
		local map_id = map_container.current_map_id
		if map_id == 1414 or map_id == 1415 then
			return
		end
		if map_id == 947 then
			map_id = "all"
		end
		local most_deadly_units = deathlogGetOrdered(_general_stats, { "all", map_id, "all", nil })
		if most_deadly_units and #most_deadly_units > 0 then
			local max_kills = most_deadly_units[1][2]
			for _, v in ipairs(most_deadly_units) do
				num_recorded_kills = num_recorded_kills + v[2]
			end

			deadliest_creatures_container:SetParent(scroll_frame.frame)
			deadliest_creatures_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 600, -10)
			deadliest_creatures_container:Show()
			deadliest_creatures_container:SetWidth(scroll_frame.frame:GetWidth() * 0.2)
			deadliest_creatures_container:SetHeight(scroll_frame.frame:GetWidth() * 0.4)
			for i = 1, 10 do
				if i <= #most_deadly_units then
					deadliest_creatures_textures[i]:SetWidth(deadliest_creatures_container:GetWidth())
					deadliest_creatures_textures[i]:SetPoint(
						"TOPLEFT",
						deadliest_creatures_container,
						"TOPLEFT",
						0,
						-30 - i * 15
					)
					deadliest_creatures_textures[i]:SetBackgroundWidth(
						deadliest_creatures_container:GetWidth() * most_deadly_units[i][2] / max_kills
					)
					deadliest_creatures_textures[i]:SetCreatureName(id_to_npc[most_deadly_units[i][1]])
					deadliest_creatures_textures[i]:SetNumKills(most_deadly_units[i][2])
					deadliest_creatures_textures[i]:SetScript("OnEnter", function()
						for _, v in ipairs(map_container.tomb_tex) do
							if v.source_id == most_deadly_units[i][1] then
								v:SetVertexColor(1, 1, 1, 1)
							else
								v:SetVertexColor(1, 1, 1, 0.1)
							end
						end
					end)
					deadliest_creatures_textures[i]:SetScript("OnLeave", function()
						for _, v in ipairs(map_container.tomb_tex) do
							v:SetVertexColor(1, 1, 1, 1)
						end
					end)
					deadliest_creatures_textures[i]:SetHeight(20)
					deadliest_creatures_textures[i]:Show()
				end
			end
		end
	end
	-- Graphs
	--
	local function updateGraph()
		LineFrame:SetParent(scroll_frame.frame)
		LineFrame.height = 225
		LineFrame.width = 400
		LineFrame.offsetx = 25
		LineFrame.zoomy = 8
		LineFrame.offsety = 0
		LineFrame:SetPoint("TOPLEFT", 590, -265)
		LineFrame:SetWidth(400)
		LineFrame:SetHeight(200)
		LineFrame:SetFrameLevel(15000)

		if LineFrame.heading == nil then
			LineFrame.heading = LineFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			LineFrame.heading:SetText("Death Level by Class PDF")
			LineFrame.heading:SetFont("Fonts\\blei00d.TTF", 18, "")
			LineFrame.heading:SetJustifyV("TOP")
			LineFrame.heading:SetTextColor(0.9, 0.9, 0.9)
			LineFrame.heading:SetPoint("TOP", LineFrame, "TOP", 25, 50)
			LineFrame.heading:Show()
		end

		if LineFrame.left == nil then
			LineFrame.left = LineFrame:CreateTexture(nil, "BACKGROUND")
			LineFrame.left:SetHeight(8)
			LineFrame.left:SetPoint("LEFT", LineFrame.heading, "LEFT", -80, 0)
			LineFrame.left:SetPoint("RIGHT", LineFrame.heading, "LEFT", -5, 0)
			LineFrame.left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
			LineFrame.left:SetTexCoord(0.81, 0.94, 0.5, 1)
		end

		if LineFrame.right == nil then
			LineFrame.right = LineFrame:CreateTexture(nil, "BACKGROUND")
			LineFrame.right:SetHeight(8)
			LineFrame.right:SetPoint("RIGHT", LineFrame.heading, "RIGHT", 80, 0)
			LineFrame.right:SetPoint("LEFT", LineFrame.heading, "RIGHT", 5, 0)
			LineFrame.right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
			LineFrame.right:SetTexCoord(0.81, 0.94, 0.5, 1)
		end

		local function createLine(name, start_coords, end_coords, color, label)
			if graph_lines[name] == nil then
				graph_lines[name] = LineFrame:CreateLine(nil, "OVERLAY")
				graph_lines[name].start_point = CreateFrame("frame", nil, LineFrame)
				graph_lines[name].end_point = CreateFrame("frame", nil, LineFrame)
			end
			graph_lines[name]:SetTexture("interface/buttons/white8x8")
			graph_lines[name]:SetThickness(1)
			graph_lines[name].start_point:SetSize(1, 1)
			graph_lines[name].start_point:Show()
			graph_lines[name].end_point:SetSize(1, 1)
			graph_lines[name].end_point:SetPoint("BOTTOMLEFT", LineFrame, "BOTTOMLEFT", end_coords[1], end_coords[2])
			graph_lines[name].start_point:SetPoint(
				"BOTTOMLEFT",
				LineFrame,
				"BOTTOMLEFT",
				start_coords[1],
				start_coords[2]
			)
			graph_lines[name].end_point:Show()
			graph_lines[name]:SetStartPoint("CENTER", graph_lines[name].start_point, 0, 0)
			graph_lines[name]:SetEndPoint("CENTER", graph_lines[name].end_point, 0, 0)
			if color == nil then
				graph_lines[name]:SetVertexColor(0.5, 0.5, 0.5, 0.5)
			else
				graph_lines[name]:SetVertexColor(color.r, color.g, color.b, 0.5)
			end
			if label then
				if graph_lines[name].label == nil then
					graph_lines[name].label = LineFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				end
				graph_lines[name].label:SetPoint("BOTTOMLEFT", start_coords[1] + label[2], start_coords[2] + label[3])
				graph_lines[name].label:SetText(label[1])
				graph_lines[name].label:SetFont("Fonts\\blei00d.TTF", 10, "")
				graph_lines[name].label:SetTextColor(0.7, 0.7, 0.7, 0.7)
			end
			graph_lines[name]:Show()
		end

		createLine(
			"y_axis",
			{ LineFrame.offsetx, LineFrame.height + LineFrame.offsety },
			{ LineFrame.offsetx, LineFrame.offsety }
		)
		createLine(
			"x_axis",
			{ LineFrame.offsetx, LineFrame.offsety },
			{ LineFrame.offsetx + LineFrame.width, LineFrame.offsety }
		)

		local function filter_by_map_function(servername, entry)
			if map_container.current_map_id == 947 then
				return true
			end
			if entry["map_id"] == map_container.current_map_id then
				return true
			end
			return false
		end

		local filtered_by_map = deathlogFilter(_deathlog_data, filter_by_map_function)
		local level_num = {}
		local ln_mean = {}
		local ln_std_dev = {}
		local total = {}
		local y_values = {}
		for k, v in pairs(class_tbl) do
			level_num[v] = {}
			total[v] = 0
			ln_mean[v] = 0
			ln_std_dev[v] = 0
			y_values[v] = {}
		end
		for i = 1, 60 do
			for k, v in pairs(class_tbl) do
				level_num[v][i] = 0
			end
		end

		for servername, entry_tbl in pairs(filtered_by_map) do
			for _, v in pairs(entry_tbl) do
				total[v["class_id"]] = total[v["class_id"]] + 1
				ln_mean[v["class_id"]] = ln_mean[v["class_id"]] + log(v["level"])
				level_num[v["class_id"]][tonumber(v["level"])] = level_num[v["class_id"]][tonumber(v["level"])] + 1
			end
		end

		for k, v in pairs(class_tbl) do
			level_num[v][1] = level_num[v][1] / total[v]
			ln_mean[v] = ln_mean[v] / total[v]
		end

		for servername, entry_tbl in pairs(filtered_by_map) do
			for _, v in pairs(entry_tbl) do
				ln_std_dev[v["class_id"]] = ln_std_dev[v["class_id"]]
					+ (log(v["level"]) - ln_mean[v["class_id"]]) * (log(v["level"]) - ln_mean[v["class_id"]])
			end
		end

		local max_y = 0
		local function logNormal(x, mean, sigma)
			return (1 / (x * sigma * sqrt(2 * 3.14))) * exp(
				(-1 / 2) * ((log(x) - mean) / sigma) * ((log(x) - mean) / sigma)
			)
		end
		for k, v in pairs(class_tbl) do
			ln_std_dev[v] = ln_std_dev[v] / total[v]

			for i = 1, 60 do
				y_values[v][i] = logNormal(i, ln_mean[v], sqrt(ln_std_dev[v]))
				if y_values[v][i] > max_y and total[v] > 2 then
					max_y = y_values[v][i]
				end
			end
		end
		LineFrame.zoomy = 1 / max_y

		for i = 1, 5 do
			createLine(
				"y_tick_" .. i .. "0",
				{ LineFrame.offsetx, (LineFrame.height + LineFrame.offsety) * i / 5 },
				{ LineFrame.offsetx + 5, (LineFrame.height + LineFrame.offsety) * i / 5 },
				nil,
				{ string.format("%.1f", i / 5 / LineFrame.zoomy * 100.0) .. "%", -23, -5 }
			)
		end

		for i = 1, 6 do
			createLine(
				"x_tick_" .. i .. "0",
				{ LineFrame.offsetx + LineFrame.width * i / 6, LineFrame.offsety },
				{ LineFrame.offsetx + LineFrame.width * i / 6, 5 },
				nil,
				{ i .. "0", -5, -11 }
			)
		end

		for i = 2, 60 do
			for k, v in pairs(class_tbl) do
				level_num[v][i] = level_num[v][i] / total[v]
				-- createLine(k..i, {25+(i-2)/60*375,level_num[v][i-1]*100*8}, {25+(i-1)/60*375,level_num[v][i]*100*8}, RAID_CLASS_COLORS[string.upper(k)])
				local y1 = logNormal(i - 1, ln_mean[v], sqrt(ln_std_dev[v]))
				local y2 = logNormal(i, ln_mean[v], sqrt(ln_std_dev[v]))
				createLine(
					k .. i,
					{ LineFrame.offsetx + (i - 2) / 60 * LineFrame.width, y1 * LineFrame.height * LineFrame.zoomy },
					{ LineFrame.offsetx + (i - 1) / 60 * LineFrame.width, y2 * LineFrame.height * LineFrame.zoomy },
					RAID_CLASS_COLORS[string.upper(k)]
				)

				if total[v] < 3 and graph_lines[k .. i] then
					graph_lines[k .. i]:Hide()
				end
			end
		end
	end

	update_functions[#update_functions + 1] = refreshDeadlyUnits
	update_functions[#update_functions + 1] = updateClassAverages
	update_functions[#update_functions + 1] = updateGraph

	local function setMapRegion(map_id)
		map_container.current_map_id = map_id
		map_container:SetParent(scroll_frame.frame)
		map_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -55)
		map_container:SetHeight(scroll_frame.frame:GetWidth() * 0.6 * 3 / 4)
		map_container:SetWidth(scroll_frame.frame:GetWidth() * 0.6)
		map_container:Show()
		if map_container.skulls_checkbox == nil then
			map_container.skulls_checkbox = CreateFrame(
				"CheckButton",
				"DeathlogSkullsCheckbox",
				scroll_frame.frame,
				"OptionsBaseCheckButtonTemplate"
			)
			map_container.skulls_checkbox:SetPoint("TOPLEFT", 25, -25)
			map_container.skulls_checkbox:SetHitRectInsets(0, -75, 0, 0)
			map_container.skulls_checkbox:SetChecked(true)
			map_container.skulls_checkbox:Show()

			map_container.skulls_checkbox_label = map_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			map_container.skulls_checkbox_label:SetPoint("LEFT", map_container.skulls_checkbox, "RIGHT", 0, 0)
			map_container.skulls_checkbox_label:SetFont("Fonts\\blei00d.TTF", 14, "OUTLINE")
			map_container.skulls_checkbox_label:SetTextColor(0.9, 0.9, 0.9)
			map_container.skulls_checkbox_label:SetJustifyH("RIGHT")
			map_container.skulls_checkbox_label:SetText("Show skulls")
			map_container.skulls_checkbox_label:Show()

			if map_container.skulls_checkbox then
				map_container.skulls_checkbox:SetScript("OnClick", function(self)
					setMapRegion(map_container.current_map_id)
				end)
			end
		end

		if map_container.map_hint == nil then
			map_container.map_hint = map_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			map_container.map_hint:SetPoint("BOTTOM", map_container, "BOTTOM", 0, 60)
			map_container.map_hint:SetFont("Fonts\\blei00d.TTF", 14, "")
			map_container.map_hint:SetTextColor(0.8, 0.8, 0.8, 0.8)
			map_container.map_hint:SetJustifyH("CENTER")
			map_container.map_hint:SetText("Click to explore statistics for a region.")
			map_container.map_hint:Show()
		end
		if map_container.heatmap_checkbox == nil then
			map_container.heatmap_checkbox = CreateFrame(
				"CheckButton",
				"DeathlogHeatmapCheckbox",
				scroll_frame.frame,
				"ChatConfigCheckButtonTemplate"
			)
			map_container.heatmap_checkbox:SetPoint("TOPLEFT", 150, -25)
			map_container.heatmap_checkbox:SetHitRectInsets(0, -75, 0, 0)
			map_container.heatmap_checkbox:SetChecked(true)
			map_container.heatmap_checkbox:Show()

			map_container.heatmap_checkbox.label = map_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			map_container.heatmap_checkbox.label:SetPoint("LEFT", map_container.heatmap_checkbox, "RIGHT", 0, 0)
			map_container.heatmap_checkbox.label:SetFont("Fonts\\blei00d.TTF", 14, "OUTLINE")
			map_container.heatmap_checkbox.label:SetTextColor(0.9, 0.9, 0.9)
			map_container.heatmap_checkbox.label:SetJustifyH("RIGHT")
			map_container.heatmap_checkbox.label:SetText("Show heatmap")
			map_container.heatmap_checkbox.label:Show()

			if map_container.heatmap_checkbox then
				map_container.heatmap_checkbox:SetScript("OnClick", function(self)
					setMapRegion(map_container.current_map_id)
				end)
			end
		end

		if map_container.darken_checkbox == nil then
			map_container.darken_checkbox = CreateFrame(
				"CheckButton",
				"DeathlogHeatmapCheckbox",
				scroll_frame.frame,
				"ChatConfigCheckButtonTemplate"
			)
			map_container.darken_checkbox:SetPoint("TOPLEFT", 275, -25)
			map_container.darken_checkbox:SetHitRectInsets(0, -75, 0, 0)
			map_container.darken_checkbox:SetChecked(true)
			map_container.darken_checkbox:Show()

			map_container.darken_checkbox.label = map_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			map_container.darken_checkbox.label:SetPoint("LEFT", map_container.darken_checkbox, "RIGHT", 0, 0)
			map_container.darken_checkbox.label:SetFont("Fonts\\blei00d.TTF", 14, "OUTLINE")
			map_container.darken_checkbox.label:SetTextColor(0.9, 0.9, 0.9)
			map_container.darken_checkbox.label:SetJustifyH("RIGHT")
			map_container.darken_checkbox.label:SetText("Darken")
			map_container.darken_checkbox.label:Show()

			if map_container.darken_checkbox then
				map_container.darken_checkbox:SetScript("OnClick", function(self)
					setMapRegion(map_container.current_map_id)
				end)
			end
		end

		local layers = C_Map.GetMapArtLayerTextures(map_container.current_map_id, 1)
		if layers == nil then
			return
		end
		for i = 1, 12 do
			map_textures[i]:SetHeight(map_container:GetWidth() / 4)
			map_textures[i]:SetWidth(map_container:GetWidth() / 4)
			map_textures[i]:SetTexture(layers[i])
			map_textures[i]:Show()
			if map_texture_masks[i] then
				map_texture_masks[i]:SetHeight(map_textures[i]:GetWidth() * 1.02)
				map_texture_masks[i]:SetWidth(map_textures[i]:GetWidth() * 1.02)
			end
		end

		for _, v in ipairs(world_map_overlay) do
			v:Hide()
		end
		other_texs = {}

		local function getOverlayTextures(map_id)
			local textures = {}
			if overlay_info[map_id] == nil then
				return nil
			end
			for k, v in pairs(overlay_info[map_id]) do
				local textureWidth, textureHeight, offsetX, offsetY = string.split(":", k)
				local fileDataIDs = { string.split(",", v) }
				table.insert(textures, {
					["fileDataIDs"] = fileDataIDs,
					["textureWidth"] = textureWidth,
					["textureHeight"] = textureHeight,
					["offsetX"] = offsetX,
					["offsetY"] = offsetY,
				})
			end
			return textures
		end

		local textures = getOverlayTextures(map_container.current_map_id)
		if textures ~= nil then
			local textureCount = 0
			for k, v in ipairs(textures) do
				local numTexturesWide = ceil(v["textureWidth"] / 256)
				local numTexturesTall = ceil(v["textureHeight"] / 256)
				local neededTextures = textureCount + (numTexturesWide * numTexturesTall)
				if neededTextures > #world_map_overlay then
					for j = #world_map_overlay + 1, neededTextures do
						world_map_overlay[j] = map_container:CreateTexture(nil, "OVERLAY")
					end
				end
				local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight
				for j = 1, numTexturesTall do
					if j < numTexturesTall then
						texturePixelHeight = 256
						textureFileHeight = 256
					else
						texturePixelHeight = mod(v["textureHeight"], 256)
						if texturePixelHeight == 0 then
							texturePixelHeight = 256
						end
						textureFileHeight = 16
						while textureFileHeight < texturePixelHeight do
							textureFileHeight = textureFileHeight * 2
						end
					end

					for k = 1, numTexturesWide do
						textureCount = textureCount + 1
						local texture = world_map_overlay[textureCount]
						if k < numTexturesWide then
							texturePixelWidth = 256
							textureFileWidth = 256
						else
							texturePixelWidth = mod(v["textureWidth"], 256)
							if texturePixelWidth == 0 then
								texturePixelWidth = 256
							end
							textureFileWidth = 16
							while textureFileWidth < texturePixelWidth do
								textureFileWidth = textureFileWidth * 2
							end
						end
						texture:SetWidth(texturePixelWidth * map_container:GetWidth() / 1000)
						texture:SetHeight(texturePixelHeight * map_container:GetWidth() / 1000)
						texture:SetTexCoord(
							0,
							texturePixelWidth / textureFileWidth,
							0,
							texturePixelHeight / textureFileHeight
						)
						texture:SetPoint(
							"TOPLEFT",
							map_textures[1],
							"TOPLEFT",
							(v["offsetX"] + (256 * (k - 1))) * map_container:GetWidth() / 1000 - 5,
							-(v["offsetY"] + (256 * (j - 1))) * map_container:GetWidth() / 1000 + 5
						)
						texture:SetTexture(v["fileDataIDs"][((j - 1) * numTexturesWide) + k], nil, nil, "TRILINEAR")
						if map_container.darken_checkbox:GetChecked() then
							texture:SetVertexColor(0.6, 0.6, 1)
						else
							texture:SetVertexColor(1, 1, 1)
						end

						texture:SetDrawLayer("OVERLAY", 5)
						texture:Show()
					end
				end
			end
		end

		local function filter_by_map_function(servername, entry)
			if entry["map_id"] == map_container.current_map_id then
				return true
			end
			return false
		end

		local filtered_by_map = deathlogFilter(_deathlog_data, filter_by_map_function)

		local num_entries = 1
		local modified_width = map_container:GetWidth() * 0.98
		local modified_height = map_container:GetHeight() * 0.87
		if map_container.tomb_tex == nil then
			map_container.tomb_tex = {}
		end
		for servername, entry_tbl in pairs(filtered_by_map) do
			for k, v in pairs(entry_tbl) do
				if v["map_id"] and v["map_pos"] then
					if map_container.tomb_tex[num_entries] == nil then
						map_container.tomb_tex[num_entries] = map_container:CreateTexture(nil, "OVERLAY")
						map_container.tomb_tex[num_entries]:SetTexture(
							"Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull"
						)
						map_container.tomb_tex[num_entries]:SetDrawLayer("OVERLAY", 7)
						map_container.tomb_tex[num_entries]:SetHeight(15)
						map_container.tomb_tex[num_entries]:SetWidth(15)
						map_container.tomb_tex[num_entries]:Hide()
					end

					map_container.tomb_tex[num_entries].map_id = v["map_id"]
					local x, y = strsplit(",", v["map_pos"], 2)
					map_container.tomb_tex[num_entries].coordinates = { x, y }
					map_container.tomb_tex[num_entries].source_id = v["source_id"]
					num_entries = num_entries + 1
				end
			end
		end
		for k, v in ipairs(map_container.tomb_tex) do
			if v.map_id == map_id then
				v:SetPoint(
					"CENTER",
					map_container,
					"TOPLEFT",
					modified_width * v.coordinates[1],
					-modified_height * v.coordinates[2]
				)
				if map_container.skulls_checkbox:GetChecked() then
					v:Show()
				else
					v:Hide()
				end
			end
		end

		local modified_width = map_container:GetWidth() * 0.98
		local modified_height = map_container:GetHeight() * 0.87
		if map_container.heatmap == nil then
			map_container.heatmap = {}
			for i = 1, 100 do
				map_container.heatmap[i] = {}
				for j = 1, 100 do
					map_container.heatmap[i][j] = map_container:CreateTexture(nil, "OVERLAY")
					map_container.heatmap[i][j]:SetDrawLayer("OVERLAY", 6)
					map_container.heatmap[i][j]:SetHeight(5)
					map_container.heatmap[i][j]:SetColorTexture(1.0, 0.1, 0.1, 0)
					map_container.heatmap[i][j]:SetWidth(7)
					map_container.heatmap[i][j]:SetPoint(
						"CENTER",
						map_container,
						"TOPLEFT",
						modified_width * i / 100,
						-modified_height * j / 100
					)
					map_container.heatmap[i][j]:Show()
					map_container.heatmap[i][j].intensity = 0.0
				end
			end
		end

		for i = 1, 100 do
			for j = 1, 100 do
				map_container.heatmap[i][j].intensity = 0.0
			end
		end
		local iv = {
			[1] = {
				[1] = 0.025,
				[2] = 0.045,
				[3] = 0.025,
			},
			[2] = {
				[1] = 0.045,
				[2] = 0.1,
				[3] = 0.045,
			},
			[3] = {
				[1] = 0.025,
				[2] = 0.045,
				[3] = 0.025,
			},
		}
		local max_intensity = 0
		for servername, entry_tbl in pairs(filtered_by_map) do
			for k, v in pairs(entry_tbl) do
				if v["map_id"] and v["map_pos"] then
					local x, y = strsplit(",", v["map_pos"], 2)
					x = ceil(x * 100)
					y = ceil(y * 100)
					for xi = 1, 3 do
						for yj = 1, 3 do
							local x_in_map = x - 2 + xi
							local y_in_map = y - 2 + yj
							if map_container.heatmap[x_in_map] and map_container.heatmap[x_in_map][y_in_map] then
								map_container.heatmap[x_in_map][y_in_map].intensity = map_container.heatmap[x_in_map][y_in_map].intensity
									+ iv[xi][yj]
								if map_container.heatmap[x_in_map][y_in_map].intensity > max_intensity then
									max_intensity = map_container.heatmap[x_in_map][y_in_map].intensity
								end
							end
						end
					end
				end
			end
		end

		for i = 1, 100 do
			for j = 1, 100 do
				if map_container.heatmap[i][j].intensity > 0.01 then
					map_container.heatmap[i][j].intensity = map_container.heatmap[i][j].intensity / max_intensity
					local alpha = map_container.heatmap[i][j].intensity * 4
					if alpha > 0.6 then
						alpha = 0.6
					end
					map_container.heatmap[i][j]:SetColorTexture(
						1.0,
						1.1 - map_container.heatmap[i][j].intensity * 4,
						0.1,
						alpha
					)
					if map_container.heatmap_checkbox:GetChecked() then
						map_container.heatmap[i][j]:Show()
					else
						map_container.heatmap[i][j]:Hide()
					end
				end
			end
		end

		for _, v in ipairs(update_functions) do
			v()
		end
	end

	map_container:SetScript("OnMouseDown", function(self, button)
		if map_container.tomb_tex then
			for _, v in ipairs(map_container.tomb_tex) do
				v:Hide()
			end

			for _, v in pairs(map_container.heatmap) do
				for _, v2 in pairs(v) do
					v2.intensity = 0
					v2:Hide()
				end
			end
		end
		if button == "RightButton" then
			info = C_Map.GetMapInfo(map_container.current_map_id)
			if info and info.parentMapID then
				parent_info = C_Map.GetMapInfo(info.parentMapID)
				if parent_info then
					setMapRegion(info.parentMapID)
					modifyTitle(parent_info.name)
					overlay_highlight:Hide()
				end
			end
		end
		if button == "LeftButton" then
			local x, y = GetCursorPosition()
			local s = UIParent:GetEffectiveScale()
			local ratio = GetScreenWidth() / GetScreenHeight()
			local modified_width = map_container:GetWidth() * 0.98
			local modified_height = map_container:GetHeight() * 0.87

			x = x / s
			y = y / s

			if x < map_container:GetLeft() or x > map_container:GetRight() then
				return
			end
			if y < map_container:GetTop() - modified_height or y > map_container:GetTop() then
				return
			end
			local l_x = (x - map_container:GetLeft()) / modified_width
			local l_y = -(y - map_container:GetTop()) / modified_height

			info = C_Map.GetMapInfoAtPosition(map_container.current_map_id, l_x, l_y)
			if info then
				overlay_highlight:Hide()
				setMapRegion(info.mapID)
				modifyTitle(info.name)
			end
		end
	end)

	map_container:SetScript("OnUpdate", function()
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		local ratio = GetScreenWidth() / GetScreenHeight()
		local modified_width = map_container:GetWidth() * 0.98
		local modified_height = map_container:GetHeight() * 0.87

		x = x / s
		y = y / s

		if x < map_container:GetLeft() or x > map_container:GetRight() then
			return
		end
		if y < map_container:GetTop() - modified_height or y > map_container:GetTop() then
			return
		end
		local l_x = (x - map_container:GetLeft()) / modified_width
		local l_y = -(y - map_container:GetTop()) / modified_height

		info = C_Map.GetMapInfoAtPosition(map_container.current_map_id, l_x, l_y)

		if info ~= nil then
			local fileDataID, atlasID, texturePercentageX, texturePercentageY, textureX, textureY, scrollChildX, scrollChildY =
				C_Map.GetMapHighlightInfoAtPosition(map_container.current_map_id, l_x, l_y)
			if fileDataID and textureX > 0 and textureY > 0 then
				overlay_highlight:SetTexture(fileDataID)
				overlay_highlight:SetPoint(
					"TOPLEFT",
					map_textures[1],
					"TOPLEFT",
					scrollChildX * modified_width,
					-scrollChildY * modified_height
				)
				overlay_highlight:SetWidth(textureX * modified_width)
				overlay_highlight:SetHeight(textureY * modified_height)
				overlay_highlight:SetTexCoord(0, texturePercentageX, 0, texturePercentageY)
				overlay_highlight:SetDrawLayer("OVERLAY", 3)
				overlay_highlight:Show()
			end
		end
	end)

	scroll_frame.frame:HookScript("OnHide", function()
		map_container:Hide()
	end)

	setMapRegion(947)
end

local function drawSettingsTab(container)
	local scroll_container = AceGUI:Create("SimpleGroup")
	scroll_container:SetFullWidth(true)
	scroll_container:SetFullHeight(true)
	scroll_container:SetLayout("Fill")
	deathlog_tabcontainer:AddChild(scroll_container)

	local scroll_frame = AceGUI:Create("ScrollFrame")
	scroll_frame:SetLayout("Flow")
	scroll_container:AddChild(scroll_frame)

	local label = AceGUI:Create("Label")
	label:SetWidth(500)
	label:SetText("Settings Tab")
	label:SetFont("Fonts\\blei00d.TTF", 15, "")
	scroll_frame:AddChild(label)
end

local function createDeathlogMenu()
	ace_deathlog_menu = AceGUI:Create("DeathlogMenu")
	_G["AceDeathlogMenu"] = ace_deathlog_menu.frame -- Close on <ESC>
	tinsert(UISpecialFrames, "AceDeathlogMenu")

	ace_deathlog_menu:SetTitle("Deathlog")
	ace_deathlog_menu:SetVersion("0.0.1")
	ace_deathlog_menu:SetStatusText("")
	ace_deathlog_menu:SetLayout("Flow")
	ace_deathlog_menu:SetHeight(_menu_height)
	ace_deathlog_menu:SetWidth(_menu_width)

	deathlog_tabcontainer = AceGUI:Create("DeathlogTabGroup") -- "InlineGroup" is also good
	local tab_table = {
		{ value = "StatisticsTab", text = "Statistics" },
		{ value = "LogTab", text = "Search" },
		{ value = "SettingsTab", text = "Settings" },
	}
	deathlog_tabcontainer:SetTabs(tab_table)
	deathlog_tabcontainer:SetFullWidth(true)
	deathlog_tabcontainer:SetFullHeight(true)
	deathlog_tabcontainer:SetLayout("Flow")

	local function SelectGroup(container, event, group)
		container:ReleaseChildren()
		if group == "StatisticsTab" then
			drawStatisticsTab(container)
		elseif group == "LogTab" then
			drawLogTab(container)
		elseif group == "SettingsTab" then
			drawSettingsTab(container)
		end
	end

	deathlog_tabcontainer:SetCallback("OnGroupSelected", SelectGroup)
	deathlog_tabcontainer:SelectTab("LogTab")

	ace_deathlog_menu:AddChild(deathlog_tabcontainer)
	return ace_deathlog_menu
end

deathlog_menu = createDeathlogMenu()

function deathlogShowMenu(deathlog_data, general_stats)
	deathlog_menu:Show()
	deathlog_tabcontainer:SelectTab("LogTab")
	_deathlog_data = deathlog_data
	_general_stats = general_stats
	setDeathlogMenuLogData(_deathlog_data)
end

function deathlogHideMenu()
	deathlog_menu:Hide()
end
