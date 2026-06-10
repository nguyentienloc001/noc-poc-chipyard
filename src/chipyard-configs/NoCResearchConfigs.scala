// NoC-PoC: SoC configs for NoC vs crossbar comparison.
// Copy into: chipyard/generators/chipyard/src/main/scala/config/
// Spec & pairing rules: docs/02-spec-soc-configs.md
// STATUS: SKELETON — node mappings must be finalized in P2 against the pinned
// Chipyard version (see generators/chipyard/src/main/scala/config/NoCConfigs.scala
// in chipyard for working examples: MultiNoCConfig, SbusRingNoCConfig).

package chipyard

import org.chipsalliance.cde.config.Config
import scala.collection.immutable.ListMap
import constellation.channel._
import constellation.routing._
import constellation.topology._
import constellation.noc.NoCParams
import constellation.protocol.{TLNoCParams, DiplomaticNetworkNodeMapping}

// ---------- Baselines (default TileLink crossbar) ----------

class Baseline2CoreConfig extends Config(
  new freechips.rocketchip.subsystem.WithNBigCores(2) ++
  new chipyard.config.AbstractConfig)

class Baseline4CoreConfig extends Config(
  new freechips.rocketchip.subsystem.WithNBigCores(4) ++
  new chipyard.config.AbstractConfig)

// 8 cores: small (no FPU) variant for FPGA fit — see docs/00 §3
class Baseline8CoreConfig extends Config(
  new freechips.rocketchip.subsystem.WithNSmallCores(8) ++
  new chipyard.config.AbstractConfig)

// ---------- NoC variants (Constellation on System Bus) ----------
// TODO(P2): inNodeMapping/outNodeMapping keys must match the actual TileLink
// edge names of the elaborated design (run with -DPRINT_NOC_MAPPING or check
// elaboration error messages listing expected names).

class NoCMesh2x2_4CoreConfig extends Config(
  new constellation.soc.WithSbusNoC(TLNoCParams(
    DiplomaticNetworkNodeMapping(
      inNodeMapping = ListMap(
        "Core 0" -> 0, "Core 1" -> 1, "Core 2" -> 2, "Core 3" -> 3),
      outNodeMapping = ListMap(
        "system[0]" -> 0, "system[1]" -> 1, "system[2]" -> 2, "system[3]" -> 3,
        "pbus" -> 0)), // TODO(P2): verify L2 bank count & names
    NoCParams(
      topology = Mesh2D(2, 2),
      channelParamGen = (a, b) => UserChannelParams(Seq.fill(8) { UserVirtualChannelParams(4) }),
      routingRelation = BlockingVirtualSubnetworksRouting(Mesh2DDimensionOrderedRouting(), 5, 1))
  )) ++
  new freechips.rocketchip.subsystem.WithNBigCores(4) ++
  new chipyard.config.AbstractConfig)

class NoCMesh3x3_8CoreConfig extends Config(
  new constellation.soc.WithSbusNoC(TLNoCParams(
    DiplomaticNetworkNodeMapping(
      inNodeMapping = ListMap(
        "Core 0" -> 0, "Core 1" -> 1, "Core 2" -> 2,
        "Core 3" -> 3, "Core 4" -> 5, "Core 5" -> 6,
        "Core 6" -> 7, "Core 7" -> 8), // node 4 (center) for L2/mem — TODO(P2)
      outNodeMapping = ListMap("system[0]" -> 4, "pbus" -> 4)),
    NoCParams(
      topology = Mesh2D(3, 3),
      channelParamGen = (a, b) => UserChannelParams(Seq.fill(8) { UserVirtualChannelParams(4) }),
      routingRelation = BlockingVirtualSubnetworksRouting(Mesh2DDimensionOrderedRouting(), 5, 1))
  )) ++
  new freechips.rocketchip.subsystem.WithNSmallCores(8) ++
  new chipyard.config.AbstractConfig)

// Secondary: ring topology, same 8-core setup — topology comparison
class NoCRing8CoreConfig extends Config(
  new constellation.soc.WithSbusNoC(TLNoCParams(
    DiplomaticNetworkNodeMapping(
      inNodeMapping = ListMap(
        "Core 0" -> 0, "Core 1" -> 1, "Core 2" -> 2, "Core 3" -> 3,
        "Core 4" -> 4, "Core 5" -> 5, "Core 6" -> 6, "Core 7" -> 7),
      outNodeMapping = ListMap("system[0]" -> 8, "pbus" -> 8)),
    NoCParams(
      topology = UnidirectionalTorus1D(9),  // TODO(P2): consider BidirectionalTorus1D
      channelParamGen = (a, b) => UserChannelParams(Seq.fill(8) { UserVirtualChannelParams(4) }),
      routingRelation = BlockingVirtualSubnetworksRouting(UnidirectionalTorus1DDatelineRouting(), 5, 1))
  )) ++
  new freechips.rocketchip.subsystem.WithNSmallCores(8) ++
  new chipyard.config.AbstractConfig)
