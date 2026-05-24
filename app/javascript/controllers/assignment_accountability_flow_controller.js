import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"

let dagreExtensionRegistered = false

const RESET_LAYOUT_CONFIRM_MESSAGE = [
  "Resetting the layout will erase, not just your changes, but all changes that have been made to this layout.",
  "",
  "This should only be done if the current layout is broken or so jumbled that starting over is the best option.",
  "",
  "Are you sure you want to reset?"
].join("\n")

function registerDagreLayout() {
  if (dagreExtensionRegistered) return true

  const register = window.cytoscapeDagre
  if (typeof register !== "function") return false

  cytoscape.use(register)
  dagreExtensionRegistered = true
  return true
}

export default class extends Controller {
  static targets = ["graph", "saveButton", "saveStatus"]

  static values = {
    elementsJson: String,
    rootsJson: { type: String, default: "[]" },
    lazy: { type: Boolean, default: false },
    highlightTiers: { type: Boolean, default: false },
    exportFilename: { type: String, default: "supply-network-graph" },
    savedPositionsJson: { type: String, default: "{}" },
    nodeFingerprint: { type: String, default: "" },
    storedNodeFingerprint: { type: String, default: "" },
    layoutUrl: String,
    canEditLayout: { type: Boolean, default: false }
  }

  connect() {
    this.savedPositionsOverride = null
    this.dragged = false
    this.layoutDirty = false
    this.savingLayout = false

    if (this.lazyValue) return
    this.render()
  }

  initGraph() {
    if (this.cy) return
    this.render()
  }

  resize() {
    this.cy?.resize()
    this.cy?.fit(undefined, 24)
  }

  exportPng() {
    this.initGraph()
    if (!this.cy) return

    this.prepareForExport()
    const dataUri = this.cy.png({
      full: true,
      scale: 2,
      bg: "#ffffff"
    })
    this.downloadDataUri(dataUri, `${this.exportFilenameValue}.png`)
  }

  exportSvg() {
    this.initGraph()
    if (!this.cy) return

    this.prepareForExport()
    const svg = this.cy.svg({
      full: true,
      bg: "#ffffff"
    })
    this.downloadBlob(svg, `${this.exportFilenameValue}.svg`, "image/svg+xml;charset=utf-8")
  }

  resetLayout(event) {
    event?.preventDefault()
    if (!this.canEditLayoutValue || !this.layoutUrlValue) return
    if (!window.confirm(RESET_LAYOUT_CONFIRM_MESSAGE)) return

    fetch(this.layoutUrlValue, {
      method: "DELETE",
      headers: this.requestHeaders()
    })
      .then((response) => {
        if (!response.ok) throw new Error("Failed to reset layout")
        this.savedPositionsOverride = {}
        this.cy?.destroy()
        this.cy = null
        this.render()
        this.setSaveStatus("")
      })
      .catch((error) => console.error(error))
  }

  render() {
    let elements = []
    let roots = []

    try {
      elements = JSON.parse(this.elementsJsonValue || "[]")
      roots = JSON.parse(this.rootsJsonValue || "[]")
    } catch {
      return
    }

    if (!elements.length || !this.hasGraphTarget) return

    const savedPositions = this.parsedSavedPositions()
    const usePreset = this.shouldUsePresetLayout(elements, savedPositions)
    const preparedElements = usePreset ? this.prepareElements(elements, savedPositions) : elements
    const useDagreLayout = !usePreset && registerDagreLayout()

    this.cy = cytoscape({
      container: this.graphTarget,
      elements: preparedElements,
      minZoom: 0.4,
      maxZoom: 2,
      style: this.graphStyles(),
      layout: usePreset ? { name: "preset", padding: 30 } : this.layoutConfig(roots, useDagreLayout),
      wheelSensitivity: 0.2
    })

    if (usePreset) {
      this.cy.fit(undefined, 24)
      this.configureInteraction()
      this.setSaveStatus("")
    } else {
      this.cy.one("layoutstop", () => {
        this.applySavedPositions(savedPositions)
        this.configureInteraction()
        this.setSaveStatus("")
      })
    }

    this.layoutDirty = false
    this.updateSaveButton()
  }

  saveLayout(event) {
    event?.preventDefault()
    this.initGraph()
    if (!this.cy || !this.canEditLayoutValue || !this.layoutUrlValue) return

    this.savingLayout = true
    this.updateSaveButton()
    this.setSaveStatus("Saving…")
    this.persistLayout()
      .then(() => {
        this.layoutDirty = false
        this.setSaveStatus("Layout saved for everyone.")
      })
      .catch(() => {
        this.layoutDirty = true
        this.setSaveStatus("Could not save layout. Try again.")
      })
      .finally(() => {
        this.savingLayout = false
        this.updateSaveButton()
      })
  }

  disconnect() {
    this.cy?.destroy()
    this.cy = null
  }

  configureInteraction() {
    if (this.canEditLayoutValue) {
      this.cy.nodes().grabify()
      this.cy.on("free", "node", () => {
        this.layoutDirty = true
        this.updateSaveButton()
        this.setSaveStatus("Unsaved changes")
      })
    } else {
      this.cy.nodes().ungrabify()
    }

    this.cy.on("grab", "node", () => {
      this.dragged = false
    })
    this.cy.on("drag", "node", () => {
      this.dragged = true
    })
    this.cy.on("tap", "node", (event) => {
      if (this.dragged) return

      const url = event.target.data("url")
      if (url) window.location.assign(url)
    })
  }

  shouldUsePresetLayout(elements, savedPositions) {
    if (!this.nodeFingerprintValue || Object.keys(savedPositions).length === 0) return false

    if (
      this.storedNodeFingerprintValue &&
      this.storedNodeFingerprintValue !== this.nodeFingerprintValue
    ) {
      return false
    }

    const nodeIds = elements
      .filter((element) => element.group === "nodes")
      .map((element) => element.data?.id)
      .filter(Boolean)

    if (nodeIds.length === 0) return false
    return nodeIds.every((id) => savedPositions[id])
  }

  prepareElements(elements, savedPositions) {
    return elements.map((element) => {
      if (element.group !== "nodes") return element

      const position = savedPositions[element.data.id]
      if (!position) return element

      return {
        ...element,
        position: { x: position.x, y: position.y }
      }
    })
  }

  applySavedPositions(savedPositions) {
    if (!this.cy || !Object.keys(savedPositions).length) {
      this.cy?.fit(undefined, 24)
      return
    }

    this.cy.nodes().forEach((node) => {
      const position = savedPositions[node.id()]
      if (position) node.position({ x: position.x, y: position.y })
    })
    this.cy.fit(undefined, 24)
  }

  parsedSavedPositions() {
    if (this.savedPositionsOverride) return this.savedPositionsOverride

    try {
      return JSON.parse(this.savedPositionsJsonValue || "{}")
    } catch {
      return {}
    }
  }

  persistLayout() {
    if (!this.cy) return Promise.reject()

    const positions = {}
    this.cy.nodes().forEach((node) => {
      const point = node.position()
      positions[node.id()] = { x: point.x, y: point.y }
    })

    return fetch(this.layoutUrlValue, {
      method: "PATCH",
      headers: this.requestHeaders(),
      body: JSON.stringify({
        positions,
        node_fingerprint: this.nodeFingerprintValue
      })
    }).then((response) => {
      if (!response.ok) throw new Error(`Save failed (${response.status})`)
    })
  }

  updateSaveButton() {
    if (!this.hasSaveButtonTarget) return

    this.saveButtonTarget.disabled = this.savingLayout
    this.saveButtonTarget.classList.toggle("btn-primary", this.layoutDirty)
    this.saveButtonTarget.classList.toggle("btn-outline-primary", !this.layoutDirty)
  }

  setSaveStatus(message) {
    if (!this.hasSaveStatusTarget) return
    this.saveStatusTarget.textContent = message
  }

  requestHeaders() {
    return {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": this.csrfToken
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  prepareForExport() {
    this.cy.resize()
    this.cy.fit(undefined, 24)
  }

  downloadDataUri(dataUri, filename) {
    const link = document.createElement("a")
    link.download = filename
    link.href = dataUri
    link.click()
  }

  downloadBlob(content, filename, mimeType) {
    const blob = new Blob([content], { type: mimeType })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.download = filename
    link.href = url
    link.click()
    URL.revokeObjectURL(url)
  }

  graphStyles() {
    const baseNodeStyle = {
      selector: "node",
      style: {
        label: "data(label)",
        "text-valign": "center",
        "text-halign": "center",
        "font-size": "11px",
        "text-wrap": "wrap",
        "text-max-width": "120px",
        shape: "roundrectangle",
        width: "label",
        height: "label",
        padding: "10px",
        "background-color": "#f8f9fa",
        "border-width": 1,
        "border-color": "#adb5bd",
        color: "#212529"
      }
    }

    const edgeStyle = {
      selector: "edge",
      style: {
        width: 2,
        "line-color": "#6c757d",
        "target-arrow-color": "#6c757d",
        "target-arrow-shape": "triangle",
        "curve-style": "bezier",
        "control-point-distances": 22,
        "control-point-weights": 0.5,
        "arrow-scale": 0.9
      }
    }

    if (this.highlightTiersValue) {
      return [
        baseNodeStyle,
        {
          selector: "node[highlightTier = 'required']",
          style: {
            "background-color": "#cfe2ff",
            "border-width": 3,
            "border-color": "#0d6efd",
            "font-weight": "bold"
          }
        },
        {
          selector: "node[highlightTier = 'suggested']",
          style: {
            "background-color": "#e7f1ff",
            "border-width": 2,
            "border-color": "#6ea8fe",
            "font-weight": "bold"
          }
        },
        {
          selector: "node[highlightTier = 'external']",
          style: {
            "background-color": "#f1f3f5",
            "border-width": 1,
            "border-color": "#ced4da"
          }
        },
        edgeStyle
      ]
    }

    return [
      baseNodeStyle,
      {
        selector: "node[?isCurrent]",
        style: {
          "background-color": "#cfe2ff",
          "border-width": 3,
          "border-color": "#0d6efd",
          "font-weight": "bold"
        }
      },
      edgeStyle
    ]
  }

  layoutConfig(roots, useDagreLayout = false) {
    if (useDagreLayout) {
      return {
        name: "dagre",
        rankDir: "LR",
        ranker: "network-simplex",
        rankSep: 90,
        nodeSep: 48,
        edgeSep: 24,
        animate: false,
        padding: 30
      }
    }

    const config = {
      name: "breadthfirst",
      directed: true,
      spacingFactor: 2,
      avoidOverlap: true,
      animate: false,
      padding: 30
    }

    if (roots.length > 0) {
      config.roots = `#${roots.join(", #")}`
    }

    return config
  }
}
