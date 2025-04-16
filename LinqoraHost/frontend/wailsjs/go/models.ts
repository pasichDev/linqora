export namespace backend {
	
	export class CpuInfo {
	    model: string;
	    cores: number;
	    theads: number;
	
	    static createFrom(source: any = {}) {
	        return new CpuInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.model = source["model"];
	        this.cores = source["cores"];
	        this.theads = source["theads"];
	    }
	}
	export class RamInfo {
	    total: number;
	    usage: number;
	
	    static createFrom(source: any = {}) {
	        return new RamInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.total = source["total"];
	        this.usage = source["usage"];
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
	    system_disk: SystemDiskInfo;
	
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

