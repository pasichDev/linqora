export namespace main {
	
	export class SystemDiskInfo {
	    total_space: number;
	    usage_space: number;
	    model_disk: string;
	    type_disk: string;
	
	    static createFrom(source: any = {}) {
	        return new SystemDiskInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.total_space = source["total_space"];
	        this.usage_space = source["usage_space"];
	        this.model_disk = source["model_disk"];
	        this.type_disk = source["type_disk"];
	    }
	}
	export class SystemInfoInitial {
	    system: string;
	    cpu: string;
	    ram_total: number;
	    ram_usage: number;
	
	    static createFrom(source: any = {}) {
	        return new SystemInfoInitial(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.system = source["system"];
	        this.cpu = source["cpu"];
	        this.ram_total = source["ram_total"];
	        this.ram_usage = source["ram_usage"];
	    }
	}

}

