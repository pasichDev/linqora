export namespace backend {
	
	export class CpuInfo {
	    model: string;
	
	    static createFrom(source: any = {}) {
	        return new CpuInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.model = source["model"];
	    }
	}
	export class RamInfo {
	    total: number;
	
	    static createFrom(source: any = {}) {
	        return new RamInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.total = source["total"];
	    }
	}
	export class SystemDiskInfo {
	    total: number;
	    usage: number;
	    model: string;
	    type: string;
	
	    static createFrom(source: any = {}) {
	        return new SystemDiskInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.total = source["total"];
	        this.usage = source["usage"];
	        this.model = source["model"];
	        this.type = source["type"];
	    }
	}
	export class SystemInfoInitial {
	    cpu_info: CpuInfo;
	    ram_info: RamInfo;
	    system_disk: SystemDiskInfo[];
	
	    static createFrom(source: any = {}) {
	        return new SystemInfoInitial(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.cpu_info = this.convertValues(source["cpu_info"], CpuInfo);
	        this.ram_info = this.convertValues(source["ram_info"], RamInfo);
	        this.system_disk = this.convertValues(source["system_disk"], SystemDiskInfo);
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}

}

export namespace database {
	
	export class CPUMetrics {
	    id: number;
	    timestamp: string;
	    temperature: number;
	    loadPercent: number;
	    processes: number;
	    threads: number;
	    freq: number;
	
	    static createFrom(source: any = {}) {
	        return new CPUMetrics(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.timestamp = source["timestamp"];
	        this.temperature = source["temperature"];
	        this.loadPercent = source["loadPercent"];
	        this.processes = source["processes"];
	        this.threads = source["threads"];
	        this.freq = source["freq"];
	    }
	}
	export class RAMMetrics {
	    id: number;
	    timestamp: string;
	    usage: number;
	    loadPercent: number;
	
	    static createFrom(source: any = {}) {
	        return new RAMMetrics(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.timestamp = source["timestamp"];
	        this.usage = source["usage"];
	        this.loadPercent = source["loadPercent"];
	    }
	}

}

