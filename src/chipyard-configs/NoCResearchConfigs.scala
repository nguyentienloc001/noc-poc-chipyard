// NoC-PoC: SoC configs for NoC vs crossbar comparison.
// Copy into: chipyard/generators/chipyard/src/main/scala/config/
// Spec & pairing rules: docs/02-spec-soc-configs.md
//
// API verified against chipyard 1.13.0 @ 69eba860 (P1 step 6):
//   - core fragments live in freechips.rocketchip.rocket (NOT .subsystem)
//   - NoC params class is constellation.protocol.SimpleTLNoCParams
//   - canonical idiom: TerminalRouter(<topo>) + TerminalRouterRouting(<routing>)
//     (see in-tree example MultiNoCConfig in NoCConfigs.scala)
// STATUS: compiles against 1.13.0. inNodeMapping/outNodeMapping values are
// PROVISIONAL — finalize in P2 against the elaborated design's TileLink edge
// names (elaboration error lists expected names on mismatch).

package chipyard

import org.chipsalliance.cde.config.Config
import scala.collection.immutable.ListMap

import constellation.channel._
import constellation.routing._
import constellation.topology._
import constellation.noc.NoCParams
import constellation.protocol.{SimpleTLNoCParams, DiplomaticNetworkNodeMapping}

// ---------- Baselines (default TileLink crossbar) ----------

class Baseline2CoreConfig extends Config(
  new freechips.rocketchip.rocket.WithNBigCores(2) ++
  new chipyard.config.AbstractConfig)

class Baseline4CoreConfig extends Config(
  new freechips.rocketchip.rocket.WithNBigCores(4) ++
  new chipyard.config.AbstractConfig)

// 8 cores: small (no FPU) variant for FPGA fit — see docs/00 §3
class Baseline8CoreConfig extends Config(
  new freechips.rocketchip.rocket.WithNSmallCores(8) ++
  new chipyard.config.AbstractConfig)

// ---------- NoC variants (Constellation on System Bus) ----------
// TODO(P2): verify node mapping keys against elaborated TileLink edge names
// and L2 bank count (AbstractConfig default). Baseline pair rule: identical
// cores/cache/memory — ONLY the sbus interconnect differs.

class NoCMesh2x2_4CoreConfig extends Config(
  new constellation.soc.WithSbusNoC(SimpleTLNoCParams(
    DiplomaticNetworkNodeMapping(
      inNodeMapping = ListMap(
        "Core 0" -> 0, "Core 1" -> 1, "Core 2" -> 2, "Core 3" -> 3,
        "serial_tl" -> 0),
      outNodeMapping = ListMap(
        "system[0]" -> 1, "pbus" -> 2)), // TODO(P2): L2 bank count & names
    NoCParams(
      topology = TerminalRouter(Mesh2D(2, 2)),
      channelParamGen = (a, b) => UserChannelParams(Seq.fill(8) { UserVirtualChannelParams(4) }),
      routingRelation = BlockingVirtualSubnetworksRouting(TerminalRouterRouting(Mesh2DEscapeRouting()), 5, 1))
  )) ++
  new freechips.rocketchip.rocket.WithNBigCores(4) ++
  new chipyard.config.AbstractConfig)

class NoCMesh3x3_8CoreConfig extends Config(
  new constellation.soc.WithSbusNoC(SimpleTLNoCParams(
    DiplomaticNetworkNodeMapping(
      inNodeMapping = ListMap(
        "Core 0" -> 0, "Core 1" -> 1, "Core 2" -> 2,
        "Core 3" -> 3, "Core 4" -> 5, "Core 5" -> 6,
        "Core 6" -> 7, "Core 7" -> 8,
        "serial_tl" -> 0),
      outNodeMapping = ListMap(
        "system[0]" -> 4, "pbus" -> 4)), // node 4 (center) for L2/periph — TODO(P2)
    NoCParams(
      topology = TerminalRouter(Mesh2D(3, 3)),
      channelParamGen = (a, b) => UserChannelParams(Seq.fill(8) { UserVirtualChannelParams(4) }),
      routingRelation = BlockingVirtualSubnetworksRouting(TerminalRouterRouting(Mesh2DEscapeRouting()), 5, 1))
  )) ++
  new freechips.rocketchip.rocket.WithNSmallCores(8) ++
  new chipyard.config.AbstractConfig)

// Secondary: ring topology, same 8-core setup — topology comparison
class NoCRing8CoreConfig extends Config(
  new constellation.soc.WithSbusNoC(SimpleTLNoCParams(
    DiplomaticNetworkNodeMapping(
      inNodeMapping = ListMap(
        "Core 0" -> 0, "Core 1" -> 1, "Core 2" -> 2, "Core 3" -> 3,
        "Core 4" -> 4, "Core 5" -> 5, "Core 6" -> 6, "Core 7" -> 7,
        "serial_tl" -> 0),
      outNodeMapping = ListMap(
        "system[0]" -> 8, "pbus" -> 8)),
    NoCParams(
      topology = TerminalRouter(BidirectionalTorus1D(9)),
      channelParamGen = (a, b) => UserChannelParams(Seq.fill(10) { UserVirtualChannelParams(4) }),
      routingRelation = BlockingVirtualSubnetworksRouting(TerminalRouterRouting(BidirectionalTorus1DShortestRouting()), 5, 2))
  )) ++
  new freechips.rocketchip.rocket.WithNSmallCores(8) ++
  new chipyard.config.AbstractConfig)
